# Mayu app

## Getting started

Start the development server:

`bin/mayu dev`

Open [`https://localhost:9292`](https://localhost:9292) with your browser.

Open `app/pages/+page.haml` with your text editor to make changes.

Routes use Klenod's `+page.haml` and `+layout.haml` conventions under
`app/pages`.

## Testing

Colocate component tests with application source files as `*.test.rb`, then run
them once with:

```bash
bin/mayu test --run
```

Run `bin/mayu test` without `--run` to watch for changes.

## Production

Build the Klenod runtime bundle and assets:

```bash
bin/mayu build
```

Set `MAYU_SECRET_KEY`, then start the production server:

```bash
bin/mayu start
```

The production server listens on `http://0.0.0.0:3333` with `h2c = true`. It
expects a proxy in front that terminates TLS and speaks HTTP/2 to it, as Fly.io
does. Browsers only use HTTP/2 over TLS, and Mayu needs HTTP/2, so you can't
open that address directly in a browser.

### Run the container locally

To try the production image with Docker or Podman, let the server terminate
TLS itself with a self-signed certificate:

1. Uncomment `gem "localhost"` in `Gemfile` and run `bundle install`.
2. In the `[production.server]` section of `mayu.toml`, set
   `listen = "https://0.0.0.0:3333"` and `self_signed_cert = true`.
3. Build and run the image:

   ```bash
   podman build -t my-app .
   podman run --rm -p 3333:3333 -e MAYU_SECRET_KEY=secret my-app
   ```

4. Open [`https://localhost:3333`](https://localhost:3333).

Revert these changes before deploying to Fly.io.

## Learn more

Find the documentation on [mayu.live/docs](https://mayu.live/docs).

Check out the [GitHub repository](https://github.com/mayu-live/framework).

## Deploy on Fly.io

The easiest way to deploy a Mayu app is on [Fly.io](https://fly.io/).

Make sure you have [`flyctl`](https://fly.io/docs/hands-on/install-flyctl/)
installed, and that you have authenticated.
(Create an account with `fly auth signup` or login with `fly auth login`).

Run the following command to launch:

`fly launch --build-only`

When asked if you like to copy the configuration, choose `yes`.

When asked if you want to tweak settings, choose `yes`.

You will probably need at least 512 MB memory.

Set a secret key with the following command:

```bash
fly secrets set MAYU_SECRET_KEY=`ruby -rsecurerandom -e "puts SecureRandom.alphanumeric(128)"`
```

Then deploy with `fly deploy`
