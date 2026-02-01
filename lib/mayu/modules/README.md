# Mayu Modules System

This directory contains the module system that powers `import(...)`, transforms
files (Haml, CSS, JS, etc.), builds dependency graphs, supports hot‑reload, and
provides source maps/backtrace rewriting.

## High‑level flow

1. `Modules::System` is created with an app root and rules.
2. `import(path, source)` resolves a file, loads/transforms it, and creates a
   `Modules::Mod` instance.
3. Each `Mod` evaluates its generated Ruby into an `Exports` module.
4. Dependencies are tracked for reload and asset management.
5. Source maps are kept so errors and backtraces map to original sources.

## Core types

### `Modules::System` (`system.rb`)

- **Thread‑local singleton:** `System.use { ... }` sets `System.current`.
- **Resolution:** uses `Resolver` to map imports to real file paths.
- **Loading:** applies `Rules::Rule` pipeline to build transformed Ruby.
- **Imports:** `import(path, source)` returns `mod::Exports::Default`.
- **Dependency graph:** `mods` store `dependencies` and `dependants`, used by
  `TSort` for update order.
- **Assets:** holds a `Mayu::Assets::Storage` queue; components can add assets.
- **Reload:** `handle_watch_events` invalidates modules + dependants, reloads,
  and signals `@on_reload`.
- **Source maps:** `read_source` returns `[transformed, source_map]`, used for
  error formatting.

### `Modules::Mod` (`mod.rb`)

- A module instance representing one file.
- Maintains:
  - `path`, `dependencies`, `dependants`, `assets`, `source_map`.
  - `order` (topological order for reload).
- `reload` re‑evaluates the module and regenerates `Exports`.
- `Exports` module is nested; `Exports::Default` is the value returned from
  `import`.
- `import` forwards to the System, and records dependency edges.

### `Modules::Resolver` (`resolver.rb`)

- Resolves `import` paths relative to the source file.
- Supports extension fallbacks and directory entry points.
- Caches resolutions for repeat imports.

### `Modules::Rules` (`rules.rb`)

- A rule is `Rule[test, loader, **options]`.
- Rules are matched by path and run in order.
- Loaders are responsible for transforming a `LoadingFile`.

### `Modules::Loaders` (`loaders/`)

- `Loaders::LoadingFile` wraps path + source + digest.
- Common loaders:
  - `Haml` → Haml AST → Ruby, then wrap in a component class.
  - `CSS`, `JavaScript`, `SVG`, `Image`, `StaticFile`, `JSON` etc.

### `Modules::Import` (`import.rb`)

- Provides `import(...)` objects that forward method/const access to the default
  export (`Exports::Default`).

### `Modules::Registry` (`registry.rb`)

- Stores module instances in constants for stable `module_path` resolution.
- Used by backtrace rewrite and source maps.

### `Modules::BacktraceRewriter` (`backtrace_rewriter.rb`)

- Rewrites backtraces using source maps so errors point to original Haml/Ruby.
- Also formats exceptions with colored context and source snippets.

## Load/transform pipeline (overview)

1. `System#import` calls `get_or_load_mod`.
2. `Resolver` chooses an absolute path.
3. `System#read_source`:
   - reads file
   - applies `Rules::Rule` transformations
   - builds a `SourceMap` from original → transformed
4. `Mod#reload` evaluates the Ruby into `Exports` and clears assets.
5. `Exports::Default` is returned from `import`.

## HMR / reload

- File watch events call `System#handle_watch_events`.
- Dirty modules + dependants are reloaded in topological order.
- `@on_reload` is signaled; sessions can listen and refresh routes.

## Assets

- Components can `add_asset` (e.g., CSS or generated bundles).
- The system collects assets for streaming to clients.

## Context + Haml notes

Haml transforms `@@var` to `@__context[:var]` in generated Ruby. This is not
module-system logic per se, but is part of the Haml transform pipeline.

## Useful entry points

- `Mayu::Modules::System.current`
- `Mayu::Modules::System.import(path, source)`
- `Mayu::Modules::System.current.format_exception(error)`
