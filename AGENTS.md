# Repository Guidelines

## Project Structure & Module Organization

- `gems/mayu-live/` is the runtime gem and `gems/mayu-build/` the development tooling gem; tests live alongside source as `*.test.rb` (e.g., `gems/mayu-live/lib/mayu/session.rb` → `gems/mayu-live/lib/mayu/session.test.rb`).
- `gems/mayu-live/lib/mayu/client/` holds the browser runtime (Node workspace).
- `example/` is a runnable sample app plus `mayu.toml` server config.
- `bin/` holds repository scripts; `gems/mayu-live/exe/mayu` is the CLI entry point.
- `vendor/` and `node_modules/` are dependency/vendor directories.

## Architecture Overview

- Server-rendered HTML with server-side state; the client runtime applies DOM patches over streaming updates.
- Components return VDOM descriptors; the server diffs component trees and sends patch instructions.
- Client stream and event serialization live under `gems/mayu-live/lib/mayu/client/src/`.

## Build, Test, and Development Commands

- `bundle install` installs Ruby dependencies.
- `npm install` installs Node dependencies (root workspace).
- `npm run build` builds the browser runtime via the `gems/mayu-live/lib/mayu/client` workspace.
- `rake test` runs the Minitest suite for both gems (glob: `gems/*/lib/**/*.test.rb`); `rake test:live` and `rake test:build` run one gem.
- `rake build` runs the client production build and packages both gems into `pkg/`.
- `cd example && bundle install && bin/mayu dev` starts the example app at `https://localhost:9292/`.
- `bin/mayu lsp` starts the language server (stdio) for editors; it finds the app via `mayu.toml`.

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
