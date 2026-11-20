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
