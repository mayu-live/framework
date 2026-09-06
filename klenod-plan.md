# Klenod migration plan

## Goal

Replace Mayu's coupled module, transform, routing, asset, bundle, source-map,
and watch implementations with Klenod. Mayu should become a consumer of
Klenod and retain only framework policy: live sessions, VDOM rendering, HTTP
dispatch, metrics, and session transfer.

This is a clean breaking migration. Existing Mayu module APIs, route naming,
and bundle contents do not need compatibility shims.

## Tracking

- Overall status: In progress
- Current milestone: 2 — Add the Mayu/Klenod boundary
- Klenod version required by Mayu: 0.0.7 source checkout (unreleased changes)
- Last updated: 2026-09-06

Update the milestone checkboxes and progress log as work lands. A milestone is
complete only when its acceptance checks pass. Milestones 3–6 may temporarily
break the full example on the migration branch, but focused suites should stay
green; the example must be restored by milestone 7.

## Decisions already made

- Use the full Klenod platform: graph, transforms, assets, runtime bundles,
  watching, source maps, and `RouterPlugin`.
- Coordinate generic integration fixes across both the Klenod and Mayu repos.
- Keep `app/` as Klenod's source root and `app/pages/` as Mayu's default route
  directory. The directory remains configurable through `RouterPlugin`.
- Adopt Klenod route filenames and bracketed route segments.
- Use Mayu defaults plus an optional application `klenod.config.rb` hook.
- Keep a single Mayu dependency set for now. `mayu-live` installs Klenod build,
  runtime, Rack, CSS, and JavaScript packages. A future `mayu-runtime` gem can
  create the runtime-only production split.
- Preserve Mayu's blurred image placeholder by adding an opt-in inline data URI
  placeholder to Klenod's generic image plugin.
- Expose Klenod `+route.rb` handlers using hybrid page/handler dispatch.
- Keep `mayu.toml` for server, session, and metrics configuration.

## Milestone 1 — Close Klenod integration gaps and release it

- [x] Add opt-in low-resolution placeholders to `ImagePlugin`.
  - Configure width, format, and quality on the plugin; Mayu defaults should
    preserve its current 16px WebP blur-up behavior.
  - Add a serializable placeholder data URI to `ImageMetadata`.
  - Keep `klenod-runtime` free of RMagick, `image_size`, and build plugins.
- [x] Verify custom-element HMR and make identities version-aware if necessary.
      A changed custom-element module must not attempt to redefine an already
      registered browser tag with incompatible code.
- [x] Add development and serialized-bundle tests for both changes.
- [ ] Run Klenod's runtime, build, Rack, CSS, JavaScript, gems, examples, and web
      suites.
- [ ] Release Klenod and record the released version in this document.

Acceptance gate: the released Klenod version provides every import value Mayu
needs in both development and a runtime-only bundle.

## Milestone 2 — Add the Mayu/Klenod boundary

- [x] Add the complete Klenod dependency set to `mayu-live` and use sibling path
      gems while coordinating development. Replace the paths with the released
      version before finishing the migration.
- [x] Introduce internal development and production providers wrapping
      `Klenod::Build::Context` and `Klenod::Runtime::Bundle`.
- [x] Give the providers one Mayu-facing interface for:
  - evaluating/exporting an entry;
  - canonicalizing a module reference;
  - finding route-scoped asset references and asset bytes;
  - formatting errors and finding original source;
  - exposing the asset base/origin.
- [x] Define Mayu's default Klenod configuration:
  - source directory: `app`;
  - router directory: `pages`;
  - entrypoints: `/root.haml` and `virtual:router`;
  - asset base: `/.mayu/assets/`;
  - Haml base class: `Mayu::Component::Base`;
  - Haml factory: `Mayu::Runtime::H`;
  - router base class: `Mayu::Route`;
  - Ruby, Intl, Haml, Router, CSS, JavaScript, SVG, Image, JSON, and static text
    plugins.
- [x] Load an optional `klenod.config.rb` from the application root, seeded with
      those defaults. It may replace the plugin list, router directory, image
      settings, source directory, asset settings, entrypoints, and output paths.
      Explicit Mayu CLI options take precedence over file configuration.
- [x] Add provider/configuration tests without switching the running framework
      away from the old system yet.

Acceptance gate: a small fixture can be collected and evaluated through the
development provider, serialized, and loaded through the production provider.

## Milestone 3 — Move Mayu components to Klenod Haml

- [x] Configure Klenod Haml variable rewriting as follows:
  - `$prop` reads component props;
  - `@@value` reads/writes component context;
  - `@value` reads/writes Mayu-managed component state;
  - underscore-prefixed framework variables remain ordinary instance variables.
- [x] Add a marshal-safe `Mayu::Component::State` store. Reads and writes use
      `[]`/`[]=`, writes schedule a rerender, and the store is rebound to its
      component after session rehydration.
- [x] Initialize the state store before calling a generated component's
      `initialize` method so assignments there retain current behavior.
- [ ] Replace generated `Styles` behavior with Klenod `ClassNames`. Update
      explicit `Styles[...]` application references; ordinary Haml class syntax
      continues to be transformed automatically.
- [x] Teach `Mayu::Runtime::H` to recognize Klenod custom-element descriptors,
      render their tag names, and preserve the associated module asset reference.
- [ ] Use Klenod image and SVG metadata directly. Update Mayu's image component
      to use the Klenod placeholder field, `src`, `srcset`, `sizes`, width, and
      height.
- [ ] Port the important existing Haml behavior tests to Klenod-backed
      integration tests: props, state assignments, context, slots, event handlers,
      inline/companion CSS, imports, whitespace, and source maps.
- [ ] Remove component-level `import`, `import?`, stylesheet aggregation, and
      other helpers that only served Mayu's transformer.

Acceptance gate: Klenod-transformed Mayu components render and update through
the existing VDOM engine, including stateful callbacks and slots.

## Milestone 4 — Cut development rendering and assets over

- [ ] Replace `Environment#modules` and the separately built Mayu router with
      the development provider plus stable root and router entry handles.
- [ ] Resolve pages, layouts, slots, closest not-found views, and closest error
      views from `virtual:router`. Route imports remain lazy.
- [ ] Return a resolved-page value containing the VDOM descriptor, HTTP status,
      canonical route module IDs, CSS references, and JavaScript references.
- [ ] Query assets from the root, rendered layouts, page, and rendered slot
      module IDs. Preserve Klenod's traversal index so root/layout CSS precedes page
      and component CSS.
- [ ] Pass stylesheet and module-script URLs explicitly into the document head.
      Remove module graph and stylesheet discovery from `VComponent`/`VDocument`.
- [ ] Serve `/.mayu/assets/` through `Klenod::Rack::AssetApp`, adapting its
      response to Mayu's protocol HTTP response. Continue serving Mayu's own client
      runtime files separately.
- [ ] Inject the module provider/error formatter into the runtime engine. Do not
      add a new global equivalent of `Modules::System.current`.
- [ ] During session Marshal dump/load, install a narrowly scoped component
      resolver that stores canonical Klenod module IDs and resolves component
      classes from the active provider. Reattach transient provider references when
      a transferred session resumes.

Acceptance gate: the example's root route renders in development with Klenod
CSS, images, SVGs, and JavaScript while callbacks and session transfer still
work.

## Milestone 5 — Adopt Klenod routing and HTTP handlers

- [ ] Migrate route conventions:
  - `page.haml` to `+page.haml`;
  - `layout.haml` to `+layout.haml`;
  - `not_found.haml` to `+not-found.haml`;
  - `:id` directories to `[id]`;
  - `::paths` directories to `[...paths]`.
- [ ] Support `+error.haml`, route groups, optional catch-alls, parallel routes,
      and intercepted routes according to `RouterPlugin`.
- [x] Add `Mayu::Route` as the generated `+route.rb` base class.
- [x] Give route methods a Mayu request wrapper exposing method, path, headers,
      body, route params, and parsed query values. Accept the usual
      `[status, headers, body]` response tuple.
- [ ] Apply hybrid dispatch after Mayu's internal session/client/asset routes:
  - HTML-preferring `GET`, `HEAD`, and `POST` use a live page when present;
  - non-HTML requests use the handler when present;
  - `PUT`, `PATCH`, `DELETE`, and `OPTIONS` use the handler;
  - unsupported methods return 405;
  - hybrid responses vary on `Accept`.
- [ ] Render Klenod's closest not-found and error views with their own layout
      chains and correct 404/500 status codes.
- [ ] Reimplement `mayu routes` from the Klenod router manifest and include the
      additional segment, handler, and special-view information.

Acceptance gate: routing tests cover static, dynamic, catch-all, grouped,
parallel, intercepted, not-found, error, page-only, handler-only, and hybrid
routes.

## Milestone 6 — Replace HMR and production bundles

- [ ] Run one Klenod watcher per development environment.
- [ ] Apply each invalidation/update once centrally, including asset writes, and
      broadcast the resulting success or failure to every live session.
- [ ] On success, refresh each session's route descriptor and route-scoped head
      assets. CSS- or JavaScript-only changes must update the head even when the
      rendered component tree is otherwise unchanged.
- [ ] On failure, keep unaffected routes serving the previous good graph and
      send source-mapped error patches for the failed modules.
- [ ] Verify recovery after syntax errors and route/component file add/remove.
- [ ] Make `mayu build` collect root and router entrypoints without evaluating
      application code, materialize Klenod assets, and serialize a Klenod runtime
      bundle.
- [ ] Make `mayu start` load that bundle with the configured source root and
      construct the production provider. Old Mayu bundle contents are intentionally
      incompatible even if the default filename remains unchanged.
- [ ] Reimplement `mayu transform` by collecting the requested module and
      displaying its Klenod transformed record and emitted assets.

Acceptance gate: development updates work for multiple live sessions, and a
fresh production process can load the built bundle, render, navigate, handle a
callback, and transfer a session between workers.

## Milestone 7 — Migrate the example, template, and documentation

- [ ] Rename every route and route segment in `example/app/pages` and the `mayu
init` template.
- [ ] Update explicit stylesheet maps from `Styles` to `ClassNames`.
- [ ] Update image rendering to Klenod metadata and its inline placeholder.
- [ ] Rename the current custom-element `.js` module to `.jsx` or `.tsx`, which
      Klenod recognizes as a custom-element module, and update its import.
- [ ] Add example coverage for `+route.rb`, `+error`, richer route segments, and
      any other new public behavior that Mayu documents.
- [ ] Update the root README, example documentation pages, generated-app README,
      Docker build, deployment files, and ignore rules.
- [ ] Document `klenod.config.rb`, the default `app/pages` choice, and how to
      configure a different `RouterPlugin#pages_dir`.

Acceptance gate: the complete example and a newly generated application work
in both development and production modes.

## Milestone 8 — Remove the old implementation and release

- [ ] Delete `lib/mayu/modules`, Mayu's route builder, old asset
      generators/storage, obsolete stylesheet/image/SVG wrappers, and superseded
      tests.
- [ ] Remove `Mayu::Modules::*`, `Mayu::StyleSheet`, and old asset APIs without
      aliases or deprecation shims.
- [ ] Remove direct gem dependencies used only by deleted code, after checking
      all remaining direct requires.
- [ ] Remove stale documentation and diagrams referring to the old graph,
      loader, asset queue, or bundle format.
- [ ] Pin the released Klenod version instead of sibling path gems.
- [ ] Run every final acceptance command and prepare the breaking Mayu release
      notes and migration guide.

Acceptance gate: no production Mayu code references `Mayu::Modules`, the old
router, or the old asset storage, and all final suites pass.

## Final test matrix

- [ ] Klenod runtime, build, Rack, CSS, JavaScript, gem, example, and web suites.
- [ ] Mayu Ruby unit and integration suite.
- [ ] Mayu browser-runtime tests and production build.
- [ ] Development smoke test of the full example.
- [ ] Production bundle/build/start smoke test in a fresh process.
- [ ] HMR success, failure, recovery, route add/remove, and asset add/remove.
- [ ] Multiple sessions receive the same update exactly once.
- [ ] Source-mapped Haml render, callback, route-handler, and reload errors.
- [ ] Component state and class references survive encrypted session transfer.
- [ ] Generated application installs, starts, builds, and serves its bundle.
- [ ] Docker/Fly-style build verifies that the selected single dependency set is
      present and functional.

The planning baseline ran 119 Mayu tests with no assertion failures. Two metrics
tests errored because the sandbox prohibited binding local TCP ports; this is an
environment limitation to account for when comparing later results.

## Progress log

Add short dated entries here. Link commits in both repositories when a
milestone spans them.

- 2026-09-05: Migration plan created; implementation not started.
- 2026-09-06: Added Klenod ImagePlugin inline placeholder support (16px WebP is
  now configurable), version-aware custom-element tags, and focused development
  and runtime-bundle tests. `base64` is now an explicit Klenod build dependency.
  Focused Klenod JavaScript and image-plugin suites pass.
- 2026-09-06: Added Mayu's Klenod path-gem dependencies, provider boundary, and
  seeded configuration DSL. A focused Mayu test verifies development and runtime
  provider exports. The legacy runtime has intentionally not been switched yet.
- 2026-09-06: Added Klenod-compatible component state and Klenod custom-element
  descriptor support in the VDOM. Focused component and VDOM suites pass.
- 2026-09-06: Added a Klenod-Haml integration fixture covering Mayu prop,
  context, and state receivers through the default provider configuration.
- 2026-09-06: Added the Klenod `+route.rb` base class and normalized route
  request value. Router configuration tests verify generated handlers inherit
  from `Mayu::Route`.
- 2026-09-06: Added a tested adapter from `Klenod::Rack::AssetApp` responses to
  Mayu Protocol HTTP responses; it will be connected during the development
  server cutover.
