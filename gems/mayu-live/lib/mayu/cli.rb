# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "optparse"

require_relative "version"
require_relative "klenod"

module Mayu
  # The `mayu` executable. With mayu-build installed, every argument is handed
  # to its command line application. Without it, this knows one command,
  # `start`, and parses it with the standard library alone, so a production
  # install needs no option parsing gem.
  module CLI
    BUILD_COMMANDS = %w[init dev test build routes graph transform lsp].freeze

    def self.call(argv, output: $stdout)
      build_cli = self.build_cli
      return build_cli.call(argv) if build_cli

      command, *args = argv

      case command
      when "start"
        start_from_argv(args, output:)
      when nil, "help", "--help", "-h"
        output.puts usage
        0
      when *BUILD_COMMANDS
        output.puts "\e[31mmayu #{command} requires the mayu-build gem.\e[0m"
        output.puts "Add it to your Gemfile's development group and run bundle install."
        1
      else
        output.puts "\e[31mUnknown command: #{command}\e[0m"
        output.puts usage
        1
      end
    end

    def self.build_cli
      require "mayu/build/cli"
      Mayu::Build::CLI
    rescue LoadError => error
      raise unless error.path == "mayu/build/cli"

      nil
    end

    def self.usage
      <<~USAGE
        Mayu v#{Mayu::VERSION}

        Usage: mayu start [--filename <path>] [--assets-dir <path>] [--source-root <path>]

        Only the production server is available. Install the mayu-build gem
        for #{BUILD_COMMANDS.join(", ")}.
      USAGE
    end

    def self.start_from_argv(args, output: $stdout)
      options = {
        filename: Klenod::BUNDLE_FILENAME,
        assets_dir: Klenod::ASSETS_DIR,
        source_root: Klenod::SOURCE_DIR
      }

      parser =
        OptionParser.new do |opts|
          opts.banner = "Usage: mayu start [options]"
          opts.on("--filename <path>", "Filename of the generated bundle") { options[:filename] = it }
          opts.on("--assets-dir <path>", "Directory with the assets written by mayu build") { options[:assets_dir] = it }
          opts.on("--source-root <path>", "Directory the bundle was built from") { options[:source_root] = it }
        end
      parser.parse!(args.dup)

      start(**options, output:)
    rescue OptionParser::ParseError => error
      output.puts "\e[31m#{error.message}\e[0m"
      output.puts parser
      1
    end

    # Starts the production server. Shared with mayu-build's `start` command so
    # both entry points behave the same.
    def self.start(filename:, assets_dir:, source_root:, output: $stdout)
      unless File.exist?(filename)
        output.puts "\e[31mCould not find \e[1m#{filename}\e[0m"
        output.puts "Try \e[1mbundle exec mayu build\e[0m to build the app."
        return 1
      end

      print_jit_message(:YJIT, output:)
      print_jit_message(:ZJIT, output:)

      require_relative "configuration"
      require_relative "server"

      Configuration.with(:production) do |config|
        bundle_path = File.expand_path(filename)
        assets_dir = File.expand_path(assets_dir)
        source_root = File.expand_path(source_root)

        Mayu::Server.new(
          config:,
          load_environment: ->(metrics:) do
            Environment.load_klenod_with_config(
              config,
              bundle_path,
              metrics:,
              source_root:,
              assets_dir:
            )
          end
        ).run
      end

      0
    rescue Interrupt
      0
    end

    def self.print_jit_message(const_name, output:)
      if RubyVM.const_defined?(const_name)
        if RubyVM.const_get(const_name).enabled?
          output.puts "\e[1m#{const_name} is enabled!\e[0m"
        else
          output.puts "\e[2m#{const_name} is disabled!\e[0m"
        end
      else
        output.puts "\e[2m#{const_name} is not supported\e[0m"
      end
    end

    private_class_method :start_from_argv, :print_jit_message
  end
end
