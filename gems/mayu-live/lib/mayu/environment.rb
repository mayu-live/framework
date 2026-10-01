# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "encrypted_marshal"
require_relative "configuration"
require_relative "component"
require_relative "metrics"
require_relative "utils"
require_relative "klenod"
require "json"

module Mayu
  class Environment
    attr_reader :config
    attr_reader :app_dir
    attr_reader :client_path
    attr_reader :runtime_init_js_path
    attr_reader :module_provider
    attr_reader :marshaller
    attr_reader :metrics

    # Answers devtools queries: `call(engine, query)` returns a
    # MessagePack-serializable value. Nil disables devtools.
    attr_accessor :inspector

    def self.client_runtime_entries_path
      File.join(__dir__, "client", "dist", "entries.json")
    end

    def self.ensure_client_runtime!
      entries_path = client_runtime_entries_path
      unless File.file?(entries_path)
        raise "Mayu browser runtime is missing at #{entries_path}. Run `npm run build` before starting the server."
      end

      filename = JSON.parse(File.read(entries_path)).fetch("init")
      init_path = File.join(File.dirname(entries_path), filename)
      unless File.file?(init_path)
        raise "Mayu browser runtime is missing at #{init_path}. Run `npm run build` before starting the server."
      end

      filename
    end

    # Set by `mayu dev`. Turns on checks that only help while developing.
    def development? = @development

    def initialize(config, module_provider:, metrics: nil, development: false)
      @config = config
      @development = development
      @app_dir = File.join(config.root, Klenod::SOURCE_DIR)
      @client_path = File.join(__dir__, "client", "dist")

      @runtime_init_js_path =
        File.join("/.mayu/runtime", self.class.ensure_client_runtime!)

      @metrics =
        metrics || Metrics::AppMetrics.setup(Prometheus::Client.registry)

      @marshaller =
        EncryptedMarshal.new(
          config.secret_key,
          ttl: config.server.transfer_timeout_seconds
        )

      @module_provider = module_provider
      @start_hooks = []
      @started = []
    end

    # Loads a prebuilt bundle. Nothing on this path may need klenod-build.
    def self.load_klenod_provider(
      config,
      bundle_path,
      source_root: nil,
      assets_dir: nil
    )
      Klenod::RuntimeProvider.load(
        bundle_path,
        source_root: source_root || File.join(config.root, Klenod::SOURCE_DIR),
        assets_dir: assets_dir || File.join(config.root, Klenod::ASSETS_DIR)
      )
    end

    def self.load_klenod_with_config(
      config,
      bundle_path,
      metrics: nil,
      source_root: nil,
      assets_dir: nil
    )
      module_provider =
        load_klenod_provider(config, bundle_path, source_root:, assets_dir:)

      new(config, module_provider:, metrics:)
    end

    def use(&)
      yield self
    end

    # Registers work to run in the worker once its App exists. A hook may
    # return something responding to `stop`, which `stop` then calls when the
    # worker drains.
    def on_start(&block)
      @start_hooks << block
    end

    def start(app)
      @started = @start_hooks.filter_map { it.call(app) }
    end

    def stop
      started = @started
      @started = []
      started.each { it.stop if it.respond_to?(:stop) }
    end
  end
end
