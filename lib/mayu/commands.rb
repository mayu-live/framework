# typed: strict
# frozen_string_literal: true

require_relative "configuration"
require_relative "commands/base"

module Mayu
  module Commands
    extend T::Sig

    sig { params(argv: T::Array[String]).void }
    def self.call(argv)
      case argv
      in ["dev", *rest]
        require_relative "commands/dev"
        Commands::Dev.new(load_config(:dev)).call(rest)
      in ["build", *rest]
        require_relative "commands/build"
        Commands::Build.new(load_config(:prod)).call(rest)
      in ["serve", *rest]
        require_relative "commands/serve"
        Commands::Serve.new(load_config(:prod)).call(rest)
      else
        puts "Invalid args: #{argv.inspect}"
        exit 1
      end
    end

    sig { params(env: Symbol).returns(Configuration) }
    def self.load_config(env)
      Mayu::Configuration.load_config(env, pwd: Dir.pwd)
    end
  end
end
