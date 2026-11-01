# Session context and application hooks

Register hooks in `mayu.rb`, inside `setup.on_worker`. Applications without
hooks keep the default behavior.

```ruby
Mayu.setup do |setup|
  setup.on_worker do |environment|
    environment.around_request do |request, next_app|
      response = next_app.call(request)
      response.headers["referrer-policy"] = "strict-origin"
      response
    end

    environment.prepare_session do |request|
      identity = Identity.prepare(request.headers)
      Mayu::Session::Preparation.new(
        context: {identity_id: identity.id},
        headers: identity.response_headers # Array of [name, value] fields
      )
    end

    environment.authorize_session do |info, request, phase|
      Identity.authorized?(info.context[:identity_id], request, phase)
    end

    environment.authorize_event do |info, event|
      Identity.active?(info.context[:identity_id])
    end
  end
end
```

The identity service in this example belongs to the application. It owns its
cookie, origin, CSRF, resource-permission, and expiry policies.

## Ordering and HTTP responses

`around_request` receives native Protocol HTTP request and response objects. It
wraps every request, including public handlers, assets, and session transports.
The first registered wrapper is outermost. Each wrapper may return a response
directly or call `next_app.call(request)` once. Headers may be added to the
returned response before it is committed.

After initial page selection, `prepare_session` runs before route resolution
constructs the component tree or a session is stored. Return
`Mayu::Session::Preparation.new(context: {}, headers: [])` or a native
`Protocol::HTTP::Response` to redirect or reject without creating a session.
It does not run for ordinary route handlers, live navigation, or reconnections.
The `:start` authorization follows preparation and precedes component creation.

Prepared response headers are appended to the document response. In particular,
separate `set-cookie` fields preserve Mayu's transport cookie. Newly issued
application context is available to the first component without modifying the
incoming Cookie header.

Once the document response or event stream has begun, application work cannot
change its HTTP status or cookies. Use a document navigation for operations
requiring an HTTP redirect or a new cookie; see `data-mayu-navigation="document"` links and
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

## Authorization and invalidation

`authorize_session` receives read-only `Session::Info` (`id`, `path`, `context`),
the current native request, and one of these phases:

| Phase       | Invocation                                                                   |
| ----------- | ---------------------------------------------------------------------------- |
| `:start`    | After preparation, before component creation                                 |
| `:resume`   | After Mayu token authentication, before opening a stream                     |
| `:events`   | After Mayu token authentication, before reading event messages               |
| `:transfer` | After transfer/token authentication, before deserializing the component tree |

The encrypted transfer envelope includes versioned, authenticated session info.
Legacy envelopes without it use `SESSION_RESTORE_FAILED` recovery.

`authorize_event` receives session info and a parsed
`Session::Events::CallbackEvent` or `NavigateEvent`. Callback checks run after
continuous-event coalescing, with the final payload, immediately before handler
invocation. Navigation checks run before route or component code. Payloads and
paths remain untrusted input. Pings and visibility events do not invoke this
hook.

Both authorization hooks must return exactly `true`. All other values reject.
Raise `Mayu::Session::Rejected.new(location: "/login")` to choose a destination.
Unexpected exceptions prevent the operation and follow ordinary error handling;
they are not reported as expired credentials.

Call `session.invalidate!(location: nil)` to invalidate an instance, or
`app.invalidate_session(id, location: nil)` from an `environment.on_start` service.
The latter affects only the current worker. The first invalidation wins;
subsequent calls return false. Invalidated sessions reject queued callbacks and
future events and cannot be transferred. Their terminal result stays in the
worker's store until normal expiry, so reconnects receive the same rejection.

Before streaming, rejection returns HTTP 403 with code
`APPLICATION_SESSION_REJECTED` and an optional `location`. Established streams
receive terminal `SessionInvalidated`. Both paths stop browser retries and pings,
clear transfer state, and reject pending callback and navigation promises. A
location causes a full document navigation with history replacement. Otherwise
the page remains visible with an expired-session notice and a Reload button.
Stream teardown occurs outside the callback fiber and lets the terminal batch
flush. An already-running operation is not rolled back.

Applications still own transaction-level permission checks, background-task
authorization, and durable revocation across workers.

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
