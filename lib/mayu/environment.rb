# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "routes"
require_relative "encrypted_marshal"
require_relative "configuration"
require_relative "system_config"
require_relative "watcher"

module Mayu
  class Environment
    attr_reader :config
    attr_reader :app_dir
    attr_reader :pages_dir
    attr_reader :assets_dir
    attr_reader :client_path
    attr_reader :runtime_js
    attr_reader :modules
    attr_reader :router
    attr_reader :marshaller

    def self.with(mayu_env)
      Configuration.with(mayu_env) do |config|
        new(config).use { |environment| yield environment }
      end
    end

    def initialize(config, router: nil, modules: nil)
      @config = config
      @app_dir = File.join(config.root, "app")
      @pages_dir = File.join(app_dir, "pages")

      @client_path = File.join(__dir__, "client", "dist")
      @assets_dir = File.join(config.root, ".assets")

      @runtime_js = load_runtime_js_path

      @marshaller =
        EncryptedMarshal.new(
          config.secret_key,
          ttl: config.server.transfer_timeout_seconds
        )

      @router = router || Mayu::Routes::Router.build(@pages_dir)
      @modules = modules || Modules::System.new(@app_dir, **SYSTEM_CONFIG)
    end

    def runtime_js_for_session_id(session_id)
      [runtime_js, session_id].join("#")
    end

    def asset_path(filename)
      File.join(assets_dir, File.expand_path(filename, "/"))
    end

    def dump
      Marshal.dump({ modules: @modules, router: @router })
    end

    def self.load(mayu_env, dumped)
      Mayu::Configuration.with(mayu_env) do |config|
        Marshal.load(dumped) => { modules:, router: }

        new(config, router:, modules:).use { |environment| yield environment }
      end
    end

    def use(&)
      @modules.use { run_watcher { yield self } }
    end

    private

    def load_runtime_js_path
      File
        .read(File.join(@client_path, "entries.json"))
        .then { JSON.parse(_1) }
        .fetch("main")
        .then { File.join("/.mayu/runtime", _1) }
    end

    def run_watcher
      yield and return unless config.server.hmr?

      task =
        Async do
          Mayu::Watcher.run(@modules) do |events|
            if events.any? { |event| is_route_event?(event) }
              Console.logger.info(self, "Rebuilding routes")
              @router = Mayu::Routes::Router.build(@pages_dir)
            end

            @modules.handle_watch_events(events)
          end
        end

      begin
        yield
      ensure
        task.stop
      end
    end

    def is_route_event?(event)
      if event in Watcher::Events::Created | Watcher::Events::Deleted
        if event.path.start_with?("/pages/")
          File.basename(event.path) in "page.haml" | "layout.haml"
        else
          false
        end
      else
        false
      end
    end
  end
end
