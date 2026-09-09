# Repository Guidelines

## Project Structure & Module Organization

- `lib/` contains the Ruby framework code; tests live alongside source as `*.test.rb` (e.g., `lib/mayu/state.rb` → `lib/mayu/state.test.rb`).
- `lib/mayu/client/` holds the browser runtime (Node workspace).
- `example/` is a runnable sample app plus `mayu.toml` server config.
- `bin/` and `exe/` provide CLI entry points and scripts.
- `vendor/` and `node_modules/` are dependency/vendor directories.

## Architecture Overview

- Server-rendered HTML with server-side state; the client runtime applies DOM patches over streaming updates.
- Components return VDOM descriptors; the server diffs component trees and sends patch instructions.
- Client stream and event serialization live under `lib/mayu/client/src/` and `lib/mayu/client/src/serializeEvent.ts`.

## Build, Test, and Development Commands

- `bundle install` installs Ruby dependencies.
- `npm install` installs Node dependencies (root workspace).
- `npm run build` builds the browser runtime via the `lib/mayu/client` workspace.
- `rake test` runs the Minitest suite (glob: `lib/**/*.test.rb`).
- `rake build` runs the client production build and builds the gem.
- `cd example && bundle install && bin/mayu dev` starts the example app at `https://localhost:9292/`.

## Coding Style & Naming Conventions

- Ruby code uses `.rb` with adjacent tests named `*.test.rb`.
- Ruby is formatted with StandardRB via `bundle exec standardrb --fix`.
- Prettier formats JavaScript, TypeScript, Markdown, HTML, CSS, JSON, and YAML via `npm run prettier`.
- `lint-staged` runs the appropriate formatter on supported files before commits; keep changes formatted.

## Testing Guidelines

- Test framework: Minitest (see `test_helper.rb` and `Rakefile`).
- Prefer higher-level tests; add focused unit tests for tricky edge cases.
- Keep example app behavior up to date; it serves as a practical integration test.

## Commit & Pull Request Guidelines

- Commit messages in this repo are short, imperative sentences (e.g., “Fix margins”, “Update dependencies and modernize code”).
- Include a clear PR description, link issues when relevant, and add screenshots/gifs for UI changes.
- Confirm tests (`rake test`) and build (`npm run build`) before opening a PR.

## Security & Configuration Tips

- Development HTTPS uses a self-signed certificate; follow README instructions if your browser blocks `https://localhost:9292/`.
- Server settings live in `example/mayu.toml`; use `[dev.server]` options for local development.
