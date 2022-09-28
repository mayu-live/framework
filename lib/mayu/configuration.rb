# typed: strict
# frozen_string_literal: true

require "toml-rb"

module Mayu
  class Configuration < T::Struct
    extend T::Sig

    CONFIG_FILE = "mayu.toml"

    class Server < T::Struct
      extend T::Sig

      const :scheme, String, default: "https"
      const :host, String, default: "127.0.0.1"
      const :port, Integer, default: 9292

      const :processes, Integer, default: 1
      const :event_source_retry_ms, Integer, default: 1000
      const :hot_swap, T::Boolean, default: false
      const :self_signed_cert, T::Boolean, default: false

      const :render_exceptions, T::Boolean, default: false

      sig { returns(URI::HTTP) }
      def uri
        URI.for(scheme, nil, host, port, nil, "/", nil, nil, nil).normalize
      end
    end

    class Instance < T::Struct
      const :app_name, String, default: ENV.fetch("FLY_APP_NAME", "mayu-live")

      const :region, String, default: ENV.fetch("FLY_REGION", "dev")

      const :alloc_id,
            String,
            default:
              ENV.fetch("FLY_ALLOC_ID", "00000000-0000-0000-0000-000000000000")
    end

    class Paths < T::Struct
      const :components, String, default: "components"
      const :pages, String, default: "pages"
      const :stores, String, default: "stores"
      const :public, String, default: "public"
      const :assets, String, default: ".assets"
      const :dist, String, default: "dist"
      const :bundle_filename, String, default: "app.mayu-bundle"
    end

    class Metrics < T::Struct
      const :enabled, T::Boolean, default: false
      const :port, Integer, default: 9090
      const :host, String, default: "127.0.0.1"
      const :path, String, default: "/metrics"
    end

    const :mode, Symbol
    const :root, String
    const :secret_key, String
    const :use_bundle, T::Boolean, default: false

    const :server, Server, default: Server.new
    const :metrics, Metrics, default: Metrics.new
    const :paths, Paths, default: Paths.new
    const :instance, Instance, default: Instance.new

    sig { params(dir: String).returns(String) }
    def self.resolve_config_file(dir = Dir.pwd)
      path = File.join(dir, CONFIG_FILE)

      return path if File.file?(path)

      parent = File.expand_path("..", dir)

      if dir == parent
        raise "Could not find #{CONFIG_FILE} in any parent directory."
      end

      resolve_config_file(parent)
    end

    sig { params(mode: Symbol, pwd: String).returns(T.attached_class) }
    def self.load_config(mode, pwd: Dir.pwd)
      file = resolve_config_file(pwd)
      root = File.dirname(file)

      config =
        T.cast(
          TomlRB.load_file(file),
          T::Hash[String, T::Hash[String, T.untyped]]
        )

      base_config = config.dig("base") || {}
      env_config = config.dig(mode.to_s) || {}

      merged_config = base_config.merge(env_config)

      secret_key =
        merged_config.fetch("secret_key") do
          ENV.fetch("MAYU_SECRET_KEY") do
            raise "secret_key is not configured (can be set with env var MAYU_SECRET_KEY)"
          end
        end

      from_hash!(
        {
          **merged_config,
          "root" => root,
          "secret_key" => secret_key,
          "mode" => mode
        }
      )
    end

    sig { params(configuration: T::Struct).void }
    def self.log_config(configuration)
      Console.logger.info(self) { make_table(configuration) }
    end

    sig do
      params(
        configuration: T::Struct,
        style: T::Hash[Symbol, T.untyped]
      ).returns(String)
    end
    def self.make_table(
      configuration,
      style: { all_separators: true, border: :unicode }
    )
      Terminal::Table
        .new do |t|
          t.headings = %w[key value type].map { "\e[1m#{_1}\e[0m" }
          t.style = style

          configuration.class.props.each do |prop, opts|
            value =
              if prop.to_s.start_with?("secret_")
                "\e[2m***hidden***\e[0m"
              else
                case configuration.send(prop)
                in T::Struct => struct
                  make_table(struct, style: { border: :unicode_round })
                in other
                  other.inspect
                end
              end

            t.add_row([prop, value, opts[:type].to_s.delete_prefix("Mayu::")])
          end
        end
        .to_s
    end
  end
end
