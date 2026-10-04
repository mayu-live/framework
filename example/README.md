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

Set `MAYU_SECRET_KEY`, then load the production bundle and start the server in
production mode.

```bash
bin/mayu start
```
