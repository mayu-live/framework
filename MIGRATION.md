# Migrating to Klenod-backed Mayu

This release replaces Mayu's internal module, routing, asset, and watcher
systems with [Klenod](https://github.com/aalin/klenod). It is a breaking
change: applications need to use Klenod's file conventions and build flow.

## Application layout

Routes live in `app/pages` by default. Rename route files to Klenod's names:

- `index.haml` becomes `+page.haml`.
- Layout files become `+layout.haml`.
- Route handlers become `+route.rb`.
- Error and not-found views become `+error.haml` and `+not-found.haml`.

Dynamic segments use Klenod conventions, such as `[id]` and `[...parts]`.
Configure a different source or pages directory in `klenod.config.rb`.

## Components and assets

Klenod compiles Haml components and owns imports, source maps, CSS, image, and
SVG assets. Replace direct use of `Styles` with the generated `ClassNames`
object. Use `import(...)` for components and assets; Mayu no longer exposes its
former module graph or asset APIs.

## Development and production

Development uses Klenod's watcher automatically. For production, build before
starting the server:

```sh
bin/mayu build
bin/mayu start
```

The build emits the Klenod runtime bundle and assets used by `mayu start`.
Generated applications include the required configuration and commands.

## Removed APIs

`Mayu::Modules`, `Mayu::Routes`, legacy asset storage/generators, stylesheet
wrappers, and the old watcher are gone. Integrations should use the injected
Klenod provider boundary instead of accessing a global Mayu module system.
