# Session context and application hooks

Most applications need two hooks: prepare the session's context, and check
whether that session remains valid. Define optional named methods in
`app/hooks.rb`:

```ruby
Identity = import("./lib/Identity.rb")

def self.prepare_session(request)
  identity = Identity.from_request(request)
  {identity_id: identity.id}
end

def self.authorize_session(session)
  Identity.active?(session.context[:identity_id])
end
```

Hooks are application modules, so imports use the same module graph as routes
and components. For the default import above, `app/lib/Identity.rb` exports its
class with `Default = Identity`. A named import can instead use
`Identity = import("./lib/Identity.rb", :Identity)`.

The hooks file and its imports are included in production bundles. In development
with HMR enabled, edits to hooks and their imports take effect on subsequent
calls without restarting. Existing sessions retain their immutable context;
their next authorization check uses the updated policy. An already-running
hook finishes with the implementation it started with. Compilation, import,
and evaluation errors are reported through the development overlay and prevent
hook execution from proceeding without its policy.
Module-level code runs when hooks are evaluated and may run again during HMR.
Keep resources requiring startup and shutdown management in process lifecycle
hooks, described below.

`Identity` belongs to the application. It owns authentication, application
identity cookies, resource permissions, expiry policy, and durable revocation.
Mayu owns browser request protection and session lifecycle checks. Both hooks
are optional; request protection is enabled even when no hooks are registered.

## Preparing a session

`prepare_session` receives the native Protocol HTTP request. Return a
symbol-keyed context hash, or `Mayu::Session::Preparation` when you also need
response headers:

```ruby
def self.prepare_session(request)
  identity = Identity.prepare(request.headers)
  Mayu::Session::Preparation.new(
    context: {identity_id: identity.id},
    headers: identity.response_headers # Array of [name, value] fields
  )
end
```

To redirect without creating a session, return
`Mayu::Session::Preparation.redirect("/login")` (303 by default, with an optional
`status:`). A native `Protocol::HTTP::Response` can also reject or redirect.

Preparation runs after initial page selection, before route resolution creates
the component tree or a session is stored. It does not run for ordinary HTTP
handlers, live navigation, or reconnections. The first validity check follows
preparation and precedes component creation.

Prepared headers are appended to the document response. Separate `set-cookie`
fields preserve Mayu's transport cookie. Newly issued context is available to
the first component without modifying the incoming Cookie header.

Once the document response or event stream has begun, application work cannot
change its HTTP status or cookies. Use a document navigation for an operation
requiring a redirect or a new cookie; see `data-mayu-navigation="document"` and
`browser.navigate(href, document: true)` in the main README.

## Immutable context

Read the snapshot through `session_context` in a component, including its
initializer and callbacks, or through `Session#context`. It is independent of
props and `H.context` providers and is never automatically emitted in HTML.
Applications should render only the values they intend to expose.

Context must be a symbol-keyed top-level hash containing nil, booleans, strings,
symbols, integers, finite floats, arrays, and hashes. Unsupported objects and
cycles raise before rendering. Mayu copies the data and recursively freezes the
snapshot. Keep database objects, service clients, and mutable application state
outside it.

The snapshot survives live navigation, fallback views, HMR, and encrypted worker
transfer. It is persisted once in engine state; the component's runtime binding
is excluded from its state dump. Restored components receive it before any
initializer runs. A new document creates a new snapshot. There is no live
context-refresh API.

## Session validity and invalidation

`authorize_session` receives read-only `Session::Info` (`id`, `path`, `context`, `origin`).
Mayu checks this policy before initial component creation, opening a stream,
reading incoming event messages, restoring a transferred component tree, and
executing each callback or live navigation. Callback checks run after
continuous-event coalescing, with the final payload, immediately before handler
invocation. Pings and visibility events do not invoke the per-event check.

Return exactly `true` to allow work. Every other value rejects the session.
Raise `Mayu::Session::Rejected.new(location: "/login")` to choose a document
navigation destination. Unexpected exceptions prevent the operation and follow
ordinary error handling; they do not invalidate the session as expired.

This is a session-validity policy: denying it terminates the whole session.
Check resource permissions inside application operations, including any
transaction-level checks. Denying access to one record should not ordinarily
expire the session. There are no periodic validity checks for otherwise idle
sessions, and an already-running operation is not rolled back.

Call `session.invalidate!(location: nil)` on an instance, or
`app.invalidate_session(id, location: nil)` from an `environment.on_start`
service. The latter affects only the current worker. The first invalidation
wins; subsequent calls return false. Invalidated sessions reject queued and
future work and cannot transfer. Their terminal result stays in the worker's
store until normal expiry so reconnects receive the same rejection.

On an initial browser navigation, rejection returns a 303 redirect when a
`location` is provided, otherwise a plain 403 response. Preparation headers,
including cookies, are preserved, and no session is stored. Non-browser page
requests retain the JSON 403 response.

For transport requests before streaming, rejection returns HTTP 403 with code
`APPLICATION_SESSION_REJECTED` and an optional `location`. Established streams
receive terminal `SessionInvalidated`. Both transport paths stop browser retries and pings,
clear transfer state, and reject pending callback and navigation promises. A
location causes a full document navigation with history replacement. Otherwise
the page remains visible with an expired-session notice and a Reload button.
Stream teardown occurs outside the callback fiber and lets the terminal batch
flush.

### Advanced validity metadata

Policies can opt into any of these keyword arguments:

```ruby
def self.authorize_session(session, request: nil, phase:, event: nil)
  Identity.authorized?(session.context[:identity_id], request, phase, event)
end
```

| Phase       | Invocation                                              |
| ----------- | ------------------------------------------------------- |
| `:start`    | After preparation, before component creation            |
| `:resume`   | After token authentication, before opening a stream     |
| `:events`   | After token authentication, before reading messages     |
| `:transfer` | After transfer/token authentication, before restoration |
| `:event`    | Immediately before a callback or live navigation        |

For `:event`, `request` is nil and `event` is a parsed
`Session::Events::CallbackEvent` or `NavigateEvent`. Other phases receive the
current native request and a nil event. Event payloads and paths remain
untrusted input. A policy that checks credentials on HTTP requests must also
support event checks without a request.

The encrypted transfer envelope includes authenticated, versioned session info
and the session's origin. Legacy envelopes without an origin use
`SESSION_RESTORE_FAILED` recovery.

## Default browser request protection

Mayu checks request origins on every session transport (including GET
reconnects), and application requests other than GET, HEAD, and OPTIONS. Checks
run before reading bodies, preparing sessions, authenticating transports, or
invoking application handlers. Normal document GET navigation and assets remain
accessible from external links. Applications must keep ordinary GET handlers
free of state-changing operations.

Protected requests follow these rules:

- `Sec-Fetch-Site: cross-site` and `same-site` are rejected. Sibling subdomains
  are not implicitly trusted.
- A supplied Origin must be a single valid HTTP(S) origin matching the expected
  scheme, host, and effective port. Null, empty, duplicate, and malformed values
  are rejected.
- Without Origin, `Sec-Fetch-Site: same-origin` is accepted. Otherwise a single
  Referer with a matching origin is required. Missing evidence is rejected.

Rejections return HTTP 403 with `REQUEST_ORIGIN_REJECTED` and
`Cache-Control: no-store`. They do not invalidate an existing session. The
browser stops connection retries and displays a Reload notice. Mayu does not
support cross-origin credentialed session transports or reflect arbitrary
origins into CORS response headers. The transport cookie retains `Secure`,
`HttpOnly`, and `SameSite=Strict`.

### Sessions and multiple domains

Mayu captures each new document's destination origin automatically, before
preparation or component initialization. It does not use the document's Origin
or Referer to establish the destination: an initial GET may arrive from an
external link.

Read the immutable value through `Session#origin` or `Session::Info#origin`.
Origins contain the scheme, lowercase hostname, and any nondefault port, without
a trailing slash. They remain fixed through live navigation, HMR, fallback
rendering, and encrypted worker transfer. Application context cannot replace
this binding.

One app can serve both `https://foo.local` and `https://bar.local`. A session
created on foo must reconnect, submit events, and transfer through foo; a valid
transport token does not allow using it through bar. The request's browser
origin checks must also pass. Changing domains requires a new document session.
An origin mismatch rejects only that request, leaving the legitimate session
valid. Ordinary HTTP handlers use their own request destination for protection.

### Reverse proxies

Without proxy configuration, Mayu uses the native request's scheme and authority
and ignores forwarded headers. When a proxy terminates HTTPS, configure its
actual connection source addresses:

```toml
[production.server]
  listen = "http://127.0.0.1:3333"
  trusted_proxies = ["127.0.0.1/32", "::1/128"]
```

No proxy addresses are trusted by default. Entries may be IPv4/IPv6 addresses or
CIDRs. Trust is based on the actual connection peer, never a header claiming to
be the client or proxy.

For requests from trusted proxies, Mayu requires exactly one
`X-Forwarded-Proto` (`http` or `https`) and one `X-Forwarded-Host` (including any
nonstandard external port). The proxy must overwrite client-supplied values,
restrict which domains reach the app, and preserve browser Origin and Fetch
Metadata headers. Missing, duplicate, malformed, and comma-separated forwarded
values are rejected. Configure the final proxy to send a single external scheme
and host; Mayu does not interpret forwarded chains, `Forwarded`, or
`X-Forwarded-Port`.

For example, an nginx proxy can overwrite both values with:

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $http_host;
```

This example assumes nginx receives the public connection directly. If another
proxy terminates TLS first, configure the final proxy to preserve the verified
external scheme and host instead of its internal address.

For a fixed-origin deployment, optional `server.public_origin` overrides both
proxy discovery and the native address:

```toml
[production.server]
  public_origin = "https://app.example"
```

It accepts an environment-variable reference such as `"$MAYU_PUBLIC_ORIGIN"` and
must contain one HTTP(S) origin without credentials, query, fragment, or a
non-root path. Leave it unset when serving multiple public origins. There is no
required `MAYU_PUBLIC_ORIGIN` environment variable in the framework. The example
app explicitly references it in production and supplies it in `fly.toml` so its
fixed-domain deployment does not depend on the h2c backend scheme.

### Webhooks and externally authenticated APIs

A `+route.rb` can exempt explicit HTTP handler methods:

```ruby
csrf_exempt "POST"

def POST(request)
  Webhook.verify_signature!(request)
  [204, {}, nil]
end
```

Use uppercase POST, PUT, PATCH, or DELETE method names. Exemptions apply only to
those methods on that handler, never to a colocated HTML page or an internal
session transport. An exempt endpoint must perform its own signature or API
authentication. Non-browser clients can also send a matching Origin to protected
endpoints; an origin check is not authentication. There is no global disable
switch and no additional CSRF cookie or form token to manage.

## Advanced request middleware

`around_request` receives native Protocol HTTP request and response objects and
wraps every request, including public handlers, assets, and session transports.
Define it in `app/hooks.rb`. It may return a response directly or call
`next_app.call(request)` once. Add headers before the returned
response is committed. The wrapper's scope does not extend to stream-body work
or component callbacks running in the session task; per-request database or
`Current` state set by a wrapper is not a callback execution context.

```ruby
def self.around_request(request, next_app)
  response = next_app.call(request)
  response.headers["referrer-policy"] = "strict-origin"
  response
end
```

## Process setup and registered hooks

Keep process lifecycle setup in the optional `mayu.rb` next to `mayu.toml`:
`before_fork` runs before workers fork, `on_worker` configures each worker, and
`environment.on_start` starts services once the app exists. Process setup is
plain Ruby and requires a server restart after changes. See the README's
[process hooks](../README.md#process-hooks).

The existing `Environment#prepare_session`, `#authorize_session`, and
`#around_request` block registration APIs remain available. A named preparation
or authorization method in `app/hooks.rb` takes precedence over its registered
counterpart. Registered request wrappers run outside the application wrapper,
with the first registered wrapper outermost. Missing methods use registered
hooks or Mayu's defaults; a broken hooks module raises rather than falling back.

## HTTP header values

`Route::Request#headers` and `Session::RequestInfo#headers` use
`Protocol::HTTP::Headers#to_h`. Values follow the field's policy: some are
strings, while many are array-like header objects. Do not assume every value is
a scalar string or flatten every field with the same separator.

```ruby
headers = Protocol::HTTP::Headers[
  [
    ["x-feature", "one"],
    ["x-feature", "two"],
    ["origin", "https://app.example"],
    ["cookie", "identity=abc"],
    ["cookie", "csrf=xyz"]
  ]
]
values = headers.to_h
Array(values["x-feature"]) # => ["one", "two"]
Array(values["cookie"]).join("; ") # => "identity=abc; csrf=xyz"

# Application policy: reject duplicate Origin values rather than choosing one.
origins = Array(values["origin"])
raise "Expected one Origin" unless origins.length == 1
origin = origins.first
```

Protocol rejects duplicates of fields it defines as singular, such as
`content-type`, with `Protocol::HTTP::DuplicateHeaderError` when indexed.
For application-defined singular fields, explicitly reject duplicates as above.

Response cookies are separate fields, never a comma-joined string:

```ruby
response = Protocol::HTTP::Response[200, [], ["OK"]]
response.headers.add("set-cookie", "identity=abc; Path=/; Secure; HttpOnly")
response.headers.add("set-cookie", "csrf=xyz; Path=/; Secure")
```
