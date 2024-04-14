require_relative "routes"
require_relative "encrypted_marshal"

module Mayu
  Environment =
    Data.define(
      :config,
      :app_dir,
      :pages_dir,
      :client_path,
      :runtime_js,
      :router,
      :marshaller
    ) do
      def self.from_config(config)
        app_dir = File.join(config.root, "app")
        pages_dir = File.join(app_dir, "pages")
        router = Mayu::Routes::Router.build(pages_dir)

        client_path = File.join(__dir__, "client", "dist")

        runtime_js =
          File
            .read(File.join(client_path, "entries.json"))
            .then { JSON.parse(_1) }
            .fetch("main")
            .then { File.join("/.mayu/runtime", _1) }

        marshaller = EncryptedMarshal.new("TODO: Get this from config", ttl: 5)

        new(
          config:,
          app_dir:,
          pages_dir:,
          client_path:,
          runtime_js:,
          router:,
          marshaller:
        )
      end

      def runtime_js_for_session_id(session_id)
        [runtime_js, session_id].join("#")
      end
    end
end
