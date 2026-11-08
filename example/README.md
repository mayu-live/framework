# [mayu.live](https://mayu.live/)

## Setup

Install dependencies

```bash
bundle install
```

## Development

Start the development server

```bash
bin/mayu dev
```

## Test

Run the component tests once:

```bash
bin/mayu test --run
```

Use `bin/mayu test` to keep watching and rerun affected tests.

## OpenID Connect demo

Open `/demos/auth`, choose **Sign in with Duende**, and use `alice` / `alice`
or `bob` / `bob`. The public test provider requires no account registration.
Sign-in opens a popup and reloads the original page after success. Blocked
popups or browsers without BroadcastChannel use ordinary full-page navigation.
The popup has no access to its opener, and completion messages carry no tokens.
Errors leave the popup open with a retry link. If Duende already remembers your
test login, the popup may complete and close immediately.
The default callback is `https://localhost:9292/auth/callback`; use HTTPS so
the browser accepts the Secure cookies. Restart the server after installing
the new `jwt` dependency.

The application hooks import `app/lib/Identity.rb`, which reads an encrypted
identity cookie into immutable session context. `app/lib/OIDC.rb` performs
discovery and authorization code + PKCE, verifies the ID token's signature,
issuer, audience, expiry, and nonce, then fetches the matching UserInfo profile.
Provider tokens are discarded. Login transactions expire after ten minutes;
signed-in identities expire after fifteen minutes.

There is no database or server-side login store. Signing out is a same-origin
document POST that clears the cookies and returns to an anonymous page. Existing
signed-in sessions reject subsequent HTTP transport requests without their login
cookie; otherwise they remain valid until expiry. Clearing a cookie cannot revoke
a copied cookie, and this demo does not sign out of the provider itself.

For another HTTPS origin, set `MAYU_PUBLIC_ORIGIN` before starting the server.
The callback always uses that configured origin, rather than incoming Host or
forwarded headers. Production cookies use `MAYU_SECRET_KEY`; local development
has a fixed demo-only fallback key. The provider credentials in `OIDC.rb` are
intentionally public demo credentials.

## Build

Builds the Klenod runtime bundle and production assets.

```bash
bin/mayu build
```

## Start

Set `MAYU_SECRET_KEY` and `MAYU_PUBLIC_ORIGIN` (the external origin, such as
`https://mayu.live`), then start the production bundle. The Fly configuration
sets the origin explicitly so session checks do not depend on the proxy's
backend scheme. Change it when deploying this example under another domain.

```bash
bin/mayu start
```
