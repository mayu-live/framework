# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "toml"

module Mayu
  module Configuration
    DOTENV_FILES = { development: %w[.env .env.local], production: %w[.env] }

    class ConfigNotFound < StandardError
    end

    class EnvironmentNotDefined < StandardError
    end

    class EnvironmentVariableNotDefined < StandardError
    end

    def self.convert_env(value)
      if var = value[/\A\$(.*)/, 1]
        ENV.fetch(var) do
          raise EnvironmentVariableNotDefined,
                "Environment variable not defined: $#{var}"
        end
      else
        value
      end
    end

    Config =
      Data.define(:root, :secret_key, :server, :metrics) do
        def self.parse(root, config)
          new(
            root:,
            secret_key: Configuration.convert_env(config.fetch("secret_key")),
            server: ServerConfig.parse(config.fetch("server")),
            metrics: MetricsConfig.parse(config.fetch("metrics"))
          )
        end
      end

    ServerConfig =
      Data.define(
        :listen,
        :hmr?,
        :render_exceptions?,
        :self_signed_cert?,
        :generate_assets?,
        :session_timeout_seconds,
        :transfer_timeout_seconds,
        :cookie_timeout_seconds
      ) do
        def self.parse(config)
          new(
            listen:
              Configuration.convert_env(
                config.fetch("listen", "https://localhost:9292")
              ),
            hmr?: config.fetch("hmr", false),
            render_exceptions?: config.fetch("render_exceptions", false),
            self_signed_cert?: config.fetch("self_signed_cert", false),
            generate_assets?: config.fetch("self_signed_cert", false),
            session_timeout_seconds:
              config.fetch("session_timout_seconds", 10).to_i,
            transfer_timeout_seconds:
              config.fetch("transfer_timeout_seconds", 10).to_i,
            cookie_timeout_seconds:
              config.fetch("transfer_timeout_seconds", 10).to_i
          )
        end
      end

    MetricsConfig =
      Data.define(:enabled?, :listen) do
        def self.parse(config)
          new(
            enabled?: config.fetch("enabled", true),
            listen: config.fetch("listen", "http://localhost:9091")
          )
        end
      end

    def self.load(filename, env)
      filename
        .then { File.read(_1) }
        .then { TOML.load(_1) }
        .fetch(env.to_s) do
          raise EnvironmentNotDefined,
                "Could not find environment #{env} in #{path}"
        end
        .then { Config.parse(Dir.pwd, _1) }
    end

    def self.with(env, &)
      path = find

      raise ConfigNotFound, "Could not find mayu.toml in #{Dir.pwd}" unless path

      root, filename = File.split(path)

      Dir.chdir(root) do
        if dotenv_files = DOTENV_FILES[env]
          require "dotenv"
          Dotenv.load(*dotenv_files)
        end

        yield self.load(filename, env)
      end
    end

    def self.find(filename = "mayu.toml", dir = Dir.pwd)
      path = File.join(dir, filename)

      if File.exist?(path)
        path
      else
        parent = File.join(dir, "..")
        return if dir == parent
        find(filename, parent)
      end
    end
  end
end
