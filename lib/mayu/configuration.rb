# typed: strict

require "toml-rb"

module Mayu
  class Configuration < T::Struct
    class Paths < T::Struct
      const :components, String, default: "components"
      const :pages, String, default: "pages"
      const :stores, String, default: "stores"
      const :public, String, default: "public"
      const :assets, String, default: ".assets"
    end

    class Metrics < T::Struct
      const :enabled, T::Boolean, default: false
      const :port, Integer, default: 9090
      const :host, String, default: "0.0.0.0"
      const :path, String, default: "/metrics"
    end

    extend T::Sig

    CONFIG_FILE = "mayu.toml"

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
      env_config = config.dig("env", mode.to_s) || {}

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
          t.headings = %w[prop value type].map { "\e[1m#{_1}\e[0m" }
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
                  other
                end
              end

            t.add_row([prop, value, opts[:type].to_s])
          end
        end
        .to_s
    end

    sig { params(configuration: T::Struct).void }
    def self.log_config(configuration)
      Console.logger.info(self) { make_table(configuration) }
    end

    const :mode, Symbol

    const :root, String
    const :secret_key, String

    const :scheme, String, default: "https"

    sig { returns(URI) }
    def uri
      URI.for(scheme, nil, host, port, nil, "/", nil, nil, nil).normalize
    end

    const :host, String, default: "0.0.0.0"
    const :port, Integer, default: 3000
    const :region, String, default: ENV.fetch("FLY_REGION", "dev")

    const :num_processes, Integer, default: 1
    const :max_sessions, Integer, default: 50
    const :sse_retry, Integer, default: 1000

    const :app_name, String, default: "mayu-live"
    const :alloc_id, String, default: "dev"

    const :metrics, Metrics, default: Metrics.new

    const :hot_swap, T::Boolean, default: false

    const :paths, Paths, default: Paths.new
    const :bundle_filename, String, default: "app.mayu-bundle"
  end
end
