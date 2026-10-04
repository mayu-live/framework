# Mayu for Zed

A Zed extension that runs `mayu lsp` for `.haml` files. Zed only starts
language servers registered by extensions, so this one registers a `mayu`
server for the `Haml` language.

## Install

1. Install the **Haml** extension from Zed's extension registry. It provides
   the `Haml` language this extension attaches to.
2. Install Rust via rustup. Zed compiles extensions to `wasm32-wasip2`, which
   rustup installs on demand.
3. In Zed, run `zed: install dev extension` and select this directory.

Open a Mayu app in Zed. The server starts through the app's `bin/mayu lsp`
when the worktree has that binstub, and otherwise through
`bundle exec mayu lsp`. Bundler and `mayu lsp` both search upwards for their
config files, so opening a folder inside the app works too.

## Nested apps

When the Mayu app lives inside the folder you open in Zed (for example
`example/` in this repository), point Zed at that app's `bin/mayu` and pass
the app directory to `mayu lsp` in the project's `.zed/settings.json`:

```json
{
  "lsp": {
    "mayu": {
      "binary": {
        "path": "/absolute/path/to/app/bin/mayu",
        "arguments": ["lsp", "/absolute/path/to/app"]
      }
    }
  }
}
```

## Rebuilding

Zed symlinks the extension directory when it is installed as a dev extension.
After changing it, use the **Rebuild** button on the extension in Zed's
extensions panel, or run `zed: install dev extension` again.

Server logs are available through `dev: open language server logs`.
