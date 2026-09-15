# frozen_string_literal: true

require "klenod/runtime"
require "klenod/rack"

require_relative "route"
require_relative "klenod/provider"
require_relative "klenod/component_resolver"
require_relative "klenod/router"
require_relative "klenod/asset_app"

module Mayu
  # Mayu's small, explicit boundary to the Klenod platform. Framework code must
  # depend on providers, rather than reaching into a build graph or runtime
  # bundle directly.
  #
  # This file is the runtime half: it needs klenod-runtime and klenod-rack and
  # nothing else, so a production server can load a prebuilt bundle without
  # klenod-build installed. The build half lives in `Mayu::Build`.
  module Klenod
    # Paths shared by `mayu build` and `mayu start`, relative to the app root.
    BUNDLE_FILENAME = "app.mayu-bundle"
    ASSETS_DIR = ".assets"
    SOURCE_DIR = "app"
  end
end
