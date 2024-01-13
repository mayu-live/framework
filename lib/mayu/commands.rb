# typed: strict
# frozen_string_literal: true

require_relative "configuration"
require_relative "commands/base"
require_relative "colors"
require_relative "banner"

module Mayu
  module Commands
    extend T::Sig

    sig { params(argv: T::Array[String]).void }
    def self.call(argv)
      puts Colors.rainbow(BANNER)

      case argv
      in ["dev", *rest]
        # Initialize RMagick on start to avoid the following error:
        #   objc[88493]: +[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called.
        #   We cannot safely call it or ignore it in the fork() child process. Crashing instead.
        require "rmagick"
        require_relative "server"
        Server.start(load_config(:dev))
      in ["devbundle", *rest]
        require_relative "server"
        Server.start(load_config(:devbundle))
      in ["build", *rest]
        require_relative "commands/build"
        Commands::Build.new(
          load_config(
            :prod,
            overrides: {
              "use_bundle" => false,
              "secret_key" => "not important, just needed to avoid an exception"
            }
          )
        ).call(rest)
      in ["serve", *rest]
        require_relative "server"
        Server.start(load_config(:prod))
      in ["init", *rest]
        require_relative "commands/init"
        Commands::Init.new.call(rest)
      else
        puts "Invalid args: #{argv.inspect}"
        exit 1
      end
    end

    sig do
      params(env: Symbol, overrides: T::Hash[String, T.untyped]).returns(
        Configuration
      )
    end
    def self.load_config(env, overrides: {})
      Mayu::Configuration.load_config(env, pwd: Dir.pwd, overrides:)
    end
  end
end
