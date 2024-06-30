# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "routes"
require_relative "encrypted_marshal"
require_relative "configuration"

module Mayu
  Environment =
    Data.define(
      :config,
      :app_dir,
      :pages_dir,
      :assets_dir,
      :client_path,
      :runtime_js,
      :router,
      :marshaller
    ) do
      def self.with(env)
        Configuration.with(env) { |config| yield from_config(config) }
      end

      def self.from_config(config)
        app_dir = File.join(config.root, "app")
        pages_dir = File.join(app_dir, "pages")
        router = Mayu::Routes::Router.build(pages_dir)

        client_path = File.join(__dir__, "client", "dist")

        assets_dir = File.join(config.root, ".assets")
        runtime_js =
          File
            .read(File.join(client_path, "entries.json"))
            .then { JSON.parse(_1) }
            .fetch("main")
            .then { File.join("/.mayu/runtime", _1) }

        marshaller =
          EncryptedMarshal.new(
            config.secret_key,
            ttl: config.server.transfer_timeout_seconds
          )

        new(
          config:,
          app_dir:,
          pages_dir:,
          client_path:,
          runtime_js:,
          assets_dir:,
          router:,
          marshaller:
        )
      end

      def runtime_js_for_session_id(session_id)
        [runtime_js, session_id].join("#")
      end

      def asset_path(filename)
        File.join(assets_dir, File.expand_path(filename, "/"))
      end
    end
end
