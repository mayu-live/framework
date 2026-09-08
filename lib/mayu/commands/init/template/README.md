# Mayu app

## Getting started

Start the development server:

`bin/mayu dev`

Open [`https://localhost:9292`](https://localhost:9292) with your browser.

Open `app/pages/+page.haml` with your text editor to make changes.

Routes use Klenod's `+page.haml` and `+layout.haml` conventions. Mayu loads an
optional `klenod.config.rb` from the application root when you need to change
the default `app/pages` route directory or Klenod plugins.

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
