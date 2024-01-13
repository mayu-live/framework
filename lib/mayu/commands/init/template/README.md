# Mayu app

## Getting started

Start the development server:

`bin/mayu dev`

Open [`https://localhost:9292`](https://localhost:9292) with your browser.

Open `app/pages/page.haml` with your text editor to make changes.

## Learn more

Find the documentation on [mayu.live/docs][https://mayu.live/docs].

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

You will need at least 512 MB memory.

Set a secret key with the following command:

```bash
fly secrets set MAYU_SECRET_KEY=`ruby -rsecurerandom -e "puts SecureRandom.alphanumeric(128)"`
```

Then deploy with `fly deploy`
