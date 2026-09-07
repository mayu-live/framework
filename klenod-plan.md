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
- Current milestone: 3–6 — Complete compatibility coverage and replace the
  remaining development/production infrastructure
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
- [x] Run Klenod's runtime, build, Rack, CSS, JavaScript, gems, examples, and web
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
- [x] Replace generated `Styles` behavior with Klenod `ClassNames`. Update
      explicit `Styles[...]` application references; ordinary Haml class syntax
      continues to be transformed automatically.
- [x] Teach `Mayu::Runtime::H` to recognize Klenod custom-element descriptors,
      render their tag names, and preserve the associated module asset reference.
- [x] Use Klenod image and SVG metadata directly. Update Mayu's image component
      to use the Klenod placeholder field, `src`, `srcset`, `sizes`, width, and
      height.
- [x] Port the important existing Haml behavior tests to Klenod-backed
      integration tests: props, state assignments, context, slots, event handlers,
      inline/companion CSS, imports, whitespace, and source maps.
- [x] Remove component-level `import`, `import?`, stylesheet aggregation, and
      other helpers that only served Mayu's transformer.

Acceptance gate: Klenod-transformed Mayu components render and update through
the existing VDOM engine, including stateful callbacks and slots.

## Milestone 4 — Cut development rendering and assets over

- [x] Replace `Environment#modules` and the separately built Mayu router with
      the development provider plus stable root and router entry handles.
- [x] Resolve pages, layouts, slots, closest not-found views, and closest error
      views from `virtual:router`. Route imports remain lazy.
  - [x] Render Klenod parallel-route matches as named children of the layout
        that owns each slot, and include their modules in route asset traversal.
  - [x] Resolve Klenod's closest `+not-found` and `+error` views, including
        their layout chains, when page resolution fails before a session starts.
  - [x] Keep Mayu's existing error-boundary and render-error-patch behavior for
        initial and live VDOM failures. Only failures while resolving a route
        before its session starts transition to the closest `+error` view, so a
        live session never loses its tree or state by being remounted as a route.
- [x] Return a resolved-page value containing the VDOM descriptor, HTTP status,
      canonical route module IDs, CSS references, and JavaScript references.
- [x] Query assets from the root, rendered layouts, page, and rendered slot
      module IDs. Preserve Klenod's traversal index so root/layout CSS precedes page
      and component CSS.
- [x] Pass stylesheet and module-script URLs explicitly into the document head.
      Remove module graph and stylesheet discovery from `VComponent`/`VDocument`.
- [x] Serve `/.mayu/assets/` through `Klenod::Rack::AssetApp`, adapting its
      response to Mayu's protocol HTTP response. Continue serving Mayu's own client
      runtime files separately.
- [x] Inject the module provider/error formatter into the runtime engine. Do not
      add a new global equivalent of `Modules::System.current`.
- [x] During session Marshal dump/load, install a narrowly scoped component
      resolver that stores canonical Klenod module IDs and resolves component
      classes from the active provider. Reattach transient provider references when
      a transferred session resumes.

Acceptance gate: the example's root route renders in development with Klenod
CSS, images, SVGs, and JavaScript while callbacks and session transfer still
work.

## Milestone 5 — Adopt Klenod routing and HTTP handlers

- [x] Migrate route conventions:
  - `page.haml` to `+page.haml`;
  - `layout.haml` to `+layout.haml`;
  - `not_found.haml` to `+not-found.haml`;
  - `:id` directories to `[id]`;
  - `::paths` directories to `[...paths]`.
- [x] Support `+error.haml`, route groups, optional catch-alls, parallel routes,
      and intercepted routes according to `RouterPlugin`.
- [x] Add `Mayu::Route` as the generated `+route.rb` base class.
- [x] Give route methods a Mayu request wrapper exposing method, path, headers,
      body, route params, and parsed query values. Accept the usual
      `[status, headers, body]` response tuple.
- [x] Apply hybrid dispatch after Mayu's internal session/client/asset routes:
  - HTML-preferring `GET`, `HEAD`, and `POST` use a live page when present;
  - non-HTML requests use the handler when present;
  - `PUT`, `PATCH`, `DELETE`, and `OPTIONS` use the handler;
  - unsupported methods return 405;
  - hybrid responses vary on `Accept`.
- [x] Render Klenod's closest not-found and error views with their own layout
      chains and correct 404/500 status codes.
  - [x] Render route-resolution failures through the closest `+error` view.
  - [x] Keep initial and live VDOM render failures under Mayu's existing
        error-boundary/render-error-patch policy rather than transitioning a
        running session to a route error view.
- [x] Reimplement `mayu routes` from the Klenod router manifest and include the
      additional segment, handler, and special-view information.

Acceptance gate: routing tests cover static, dynamic, catch-all, grouped,
parallel, intercepted, not-found, error, page-only, handler-only, and hybrid
routes.

## Milestone 6 — Replace HMR and production bundles

- [x] Run one Klenod watcher per development environment.
- [x] Apply each invalidation/update once centrally, including asset writes, and
      broadcast the resulting success or failure to every live session.
- [x] On success, refresh each session's route descriptor and route-scoped head
      assets. CSS- or JavaScript-only changes must update the head even when the
      rendered component tree is otherwise unchanged.
- [x] On failure, keep unaffected routes serving the previous good graph and
      send source-mapped error patches for the failed modules.
- [x] Verify recovery after syntax errors and route/component file add/remove.
- [x] Make `mayu build` collect root and router entrypoints without evaluating
      application code, materialize Klenod assets, and serialize a Klenod runtime
      bundle.
- [x] Make `mayu start` load that bundle with the configured source root and
      construct the production provider. Old Mayu bundle contents are intentionally
      incompatible even if the default filename remains unchanged.
- [x] Reimplement `mayu transform` by collecting the requested module and
      displaying its Klenod transformed record and emitted assets.

Acceptance gate: development updates work for multiple live sessions, and a
fresh production process can load the built bundle, render, navigate, handle a
callback, and transfer a session between workers.

## Milestone 7 — Migrate the example, template, and documentation

- [x] Rename every route and route segment in `example/app/pages` and the `mayu
init` template.
- [x] Update explicit stylesheet maps from `Styles` to `ClassNames`.
- [x] Update image rendering to Klenod metadata and its inline placeholder.
- [x] Rename the current custom-element `.js` module to `.jsx` or `.tsx`, which
      Klenod recognizes as a custom-element module, and update its import.
- [ ] Add example coverage for `+route.rb`, `+error`, richer route segments, and
      any other new public behavior that Mayu documents.
  - [x] Add and test an example `GET /api/health` `+route.rb` handler.
  - [x] Add a root `+error.haml` view and verify that Klenod resolves it at 500.
  - [x] Add and test a grouped optional catch-all route under `/demos/segments`.
- [ ] Update the root README, example documentation pages, generated-app README,
      Docker build, deployment files, and ignore rules.
  - [x] Update the example stylesheet guide to describe Klenod `ClassNames`.
  - [x] Make the example Docker image start the Klenod production bundle with
        `bin/mayu start`.
  - [x] Replace the obsolete legacy-transformer walkthrough in the root README
        with the Klenod component boundary and `mayu transform` command.
  - [x] Update the root README's server configuration examples for the active
        development/production keys and Klenod build/start flow.
  - [x] Remove the stale example route/module graph diagram.
  - [x] Document Klenod route/configuration defaults and the production bundle
        flow in the generated-app README.
  - [x] Clarify Klenod production build/start requirements in the example README.
  - [ ] Make the example Docker build work with the temporary sibling Klenod
        path gems (or switch it to released gems once Klenod is published). Its
        current `example/` build context cannot contain `../../../klenod`.
- [x] Document `klenod.config.rb`, the default `app/pages` choice, and how to
      configure a different `RouterPlugin#pages_dir`.

Acceptance gate: the complete example and a newly generated application work
in both development and production modes.

## Follow-up candidates

- [ ] Evaluate a small Klenod client-entry plugin for Mayu's browser runtime
      after the core migration is complete. It could replace the framework's
      shared `/.mayu/init.js` module, but should remain deferred while that
      endpoint is sufficient and keeps the client/session protocol explicit.

## Milestone 8 — Remove the old implementation and release

- [x] Delete `lib/mayu/modules`, Mayu's route builder, old asset
      generators/storage, obsolete stylesheet/image/SVG wrappers, and superseded
      tests.
  - [x] Delete the unreachable legacy transformer implementation from `mayu transform`.
  - [x] Delete the legacy module tree, route builder, and stylesheet wrappers.
  - [x] Delete the unused legacy asset generators and storage.
  - [x] Remove the legacy route-resolution, asset-serving, and watcher fallbacks
        from the active Mayu environment, session, and server paths.
  - [x] Make VDOM error reporting and session-transfer component restoration use
        the injected Klenod provider/resolver without legacy module fallbacks.
  - [x] Convert VDOM serialization and context fixtures from thread-local module
        systems to injected component resolvers.
- [x] Remove `Mayu::Modules::*`, `Mayu::StyleSheet`, and old asset APIs without
      aliases or deprecation shims.
- [x] Remove direct gem dependencies used only by deleted code, after checking
      all remaining direct requires.
  - [x] Remove Mayu's direct legacy transform/image dependencies; Klenod Build
        retains the dependencies it needs for its own plugins.
  - [x] Remove the unused legacy `listen` watcher dependency.
  - [x] Remove the redundant direct `syntax_tree` dependency; the remaining
        `syntax_tree-xml` test helper owns it transitively.
- [x] Remove stale documentation and diagrams referring to the old graph,
      loader, asset queue, or bundle format.
- [ ] Pin the released Klenod version instead of sibling path gems.
- [ ] Run every final acceptance command and prepare the breaking Mayu release
      notes and migration guide.

Acceptance gate: no production Mayu code references `Mayu::Modules`, the old
router, or the old asset storage, and all final suites pass.

## Final test matrix

- [x] Klenod runtime, build, Rack, CSS, JavaScript, gem, example, and web suites.
- [x] Mayu Ruby unit and integration suite.
- [x] Mayu browser-runtime tests and production build.
- [x] Development smoke test of the full example.
- [x] Production bundle/build/start smoke test in a fresh process.
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

- 2026-09-07: Removed the unreachable legacy `Mayu::Watcher`, its direct
  `listen` dependency, and the unused `AddStyleSheet` patch. Updated the
  architecture guide to describe Klenod as the application compiler, router,
  asset pipeline, and HMR provider. Client tests pass (13 tests), and the full
  Mayu suite passes (124 runs, 418 assertions).
- 2026-09-07: Audited Mayu's remaining direct dependencies and removed the
  redundant direct `syntax_tree` declaration. The retained `syntax_tree-xml`
  test helper supplies it transitively; the full Mayu suite passes (124 runs,
  418 assertions).
- 2026-09-07: Failed Klenod development updates now rewrite exception
  backtraces through Klenod's source maps before emitting Mayu render-error
  patches. The existing graph remains active after a failure, and focused
  session coverage verifies the patch's original source and rewritten location.
- 2026-09-07: Updated example component and callback documentation to show
  Klenod-generated `Mayu::Runtime::H` output and the current callback helper.
  Replaced the deleted transformer-fixture link with Klenod's Haml-plugin
  coverage, verified both pages with `mayu transform`, and synchronized the
  example lockfile with Mayu's removed direct dependencies.
- 2026-09-07: Ran Klenod's complete acceptance suite: runtime, build, test,
  Rack, JavaScript, CSS, and meta gems; standalone, box, performance, and web
  examples; and release tooling all pass (750 runs, 4,170 assertions).
- 2026-09-07: Re-ran the Mayu suite (124 runs, 420 assertions) and browser
  runtime tests (13 tests). Built the example production Klenod bundle with a
  temporary secret, started it in a fresh process, fetched its HTTPS root page,
  verified Klenod CSS asset URLs, and stopped the temporary server.
- 2026-09-07: Ran the example development server, fetched its HTTPS root page,
  verified Klenod CSS assets, and stopped it. Fixed the client patch dispatcher
  tuple type so `npm run build` completes without TypeScript diagnostics; the
  browser suite still passes (13 tests).
- 2026-09-06: Added executable example coverage for a grouped optional
  catch-all route, corrected the example production Docker command, and updated
  the root and example documentation for Klenod `ClassNames`, transformation,
  and production build/start behavior. Removed the unreachable legacy
  transformer implementation from `mayu transform`; the full Mayu suite passes
  (171 runs, 524 assertions).
- 2026-09-06: Added the Mayu adapter for Klenod slots and opt-in event-handler
  references. The example root page and `/demos/form` now server-render through
  Klenod with slots, callbacks, styles, and assets present in the document.
- 2026-09-06: Updated the example bundle to use the sibling Klenod checkout and
  repaired Klenod route-component syntax exposed by SSR. All 40 discovered
  example routes, including dynamic and catch-all routes, render successfully
  through Klenod with the example dependency bundle.
- 2026-09-06: Switched `mayu build` to Klenod's root/router bundle and asset
  build, and made production environments load that runtime bundle without
  constructing the legacy router or module system. The Mayu suite passes (151
  runs, 440 assertions), and the example production build completes successfully.
- 2026-09-06: Replaced the development watcher path with Klenod's watcher. It
  applies each invalidation once, writes changed assets, and fans the result out
  to subscribed live sessions; each session refreshes its descriptor and head
  assets from that shared result. The Mayu suite passes (154 runs, 451 assertions).
- 2026-09-06: Migrated `mayu routes` to Klenod's route manifest, including route
  kinds, handlers, layouts, and special views.
- 2026-09-06: Migrated `mayu transform` to display Klenod's collected transformed
  record and emitted assets.
- 2026-09-06: Added HMR recovery coverage: failed Klenod Haml updates publish no
  asset writes, and the next valid update restores the development graph.
- 2026-09-06: Removed the final VDOM stylesheet discovery path from the legacy
  module graph. Route-scoped Klenod assets are now the sole source of document
  stylesheets and module scripts.
- 2026-09-06: Migrated generated applications to Klenod's `+page.haml` and
  `+layout.haml` route filenames. The template resolves its root route through
  the Klenod provider.
- 2026-09-06: Renamed the custom-element demo source to `.jsx` and added an
  example-session regression test for its generated tag and module asset.
- 2026-09-06: Render Klenod parallel route matches in their owning Mayu layout
  slots and collect their route modules as assets.
- 2026-09-06: Added Klenod special-view resolution for 404s and page-resolution
  failures. A page that fails during resolution now renders the nearest
  `+error` view with status 500 and the original exception as a prop.
- 2026-09-06: Made `klenod.config.rb` `pages_dir` overrides reconfigure the
  active Klenod router plugin; a configured source root and routes directory
  now resolve through the development provider end to end.
- 2026-09-06: Updated the route documentation to use Klenod's `+page`,
  `+layout`, dynamic-segment, and not-found conventions, and documented
  `klenod.config.rb` route-directory overrides.
- 2026-09-06: Verified that grouped, optional catch-all, and intercepted routes
  resolve through Mayu's Klenod adapter; parallel routes and error views were
  already covered by their dedicated adapter tests.
- 2026-09-06: Verified the Klenod CSS companion `ClassNames` object and the
  image plugin's 16px WebP inline placeholder configuration used by example
  components.
- 2026-09-06: Chose to preserve Mayu VDOM error boundaries and render-error
  patches for initial and live component failures. Only route-resolution
  failures before session startup render the nearest Klenod `+error` view.
- 2026-09-06: Added a development-provider regression test for recursive route
  CSS collection. Klenod preserves root, layout, and page stylesheet order.
- 2026-09-06: Corrected the VDOM implementation notes: route-scoped Klenod
  assets are passed into the document head explicitly, not discovered by VNodes.
- 2026-09-06: Expanded Klenod-backed Haml integration coverage for props, state,
  context, imports, slots, class names, whitespace, event callbacks, and source
  maps. Fixed development-provider error formatting to use the collected graph's
  module map rather than the context object.
- 2026-09-06: Confirmed that normal development and production environments
  carry only Klenod providers; legacy `modules` and router state remain solely
  for the later removal milestone.
- 2026-09-06: Built the complete example with a throwaway production secret;
  Klenod generated `app.mayu-bundle` successfully. A production server smoke
  test remains pending because the active development server owns its metrics
  port.
- 2026-09-06: Started that production bundle in a fresh process and fetched the
  complete HTML root page with `Accept: text/html`. It served Klenod CSS, image,
  and callback assets correctly; the temporary controller was then stopped.

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
- 2026-09-06: Made the VDOM's error formatting provider-backed and stopped
  provider-backed components from consulting the legacy module graph for CSS.
