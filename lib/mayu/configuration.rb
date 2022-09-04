# typed: strict

require "toml-rb"

module Mayu
  class Configuration < T::Struct
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

    sig { params(env: Symbol, pwd: String).returns(T.attached_class) }
    def self.load_config(env, pwd: Dir.pwd)
      file = resolve_config_file(pwd)
      root = File.dirname(file)

      config =
        T.cast(
          TomlRB.load_file(file, symbolize_keys: true),
          T::Hash[Symbol, T::Hash[Symbol, T.untyped]]
        )

      base_config = config.dig(:base) || {}
      env_config = config.dig(:env, env) || {}

      merged_config = base_config.merge(env_config)

      secret_key =
        merged_config.fetch(:secret_key) do
          ENV.fetch("MAYU_SECRET_KEY") do
            raise "secret_key is not configured (can be set with env var MAYU_SECRET_KEY)"
          end
        end

      new(**merged_config, root:, secret_key:)
    end

    sig { params(configuration: Configuration).void }
    def self.log_config(configuration)
      Console
        .logger
        .info(self) do
          Terminal::Table.new do |t|
            t.headings = %w[prop value type].map { "\e[1m#{_1}\e[0m" }
            t.style = { all_separators: true, border: :unicode }

            Configuration.props.each do |prop, opts|
              value =
                if prop.to_s.start_with?("secret_")
                  "\e[2m***hidden***\e[0m"
                else
                  configuration.send(prop).to_s
                end

              t.add_row([prop, value, opts[:type].to_s])
            end
          end
        end
    end

    const :root, String
    const :secret_key, String

    const :host, String, default: "0.0.0.0"
    const :port, Integer, default: 3000

    const :num_processes, Integer, default: 1
    const :max_sessions, Integer, default: 50

    const :hot_reload, T::Boolean, default: false
  end
end
