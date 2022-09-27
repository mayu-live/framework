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
        require_relative "server"
        Server.start(load_config(:dev))
      in ["build", *rest]
        require_relative "commands/build"
        Commands::Build.new(load_config(:prod)).call(rest)
      in ["serve", *rest]
        require_relative "server"
        Server.start(load_config(:prod))
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
