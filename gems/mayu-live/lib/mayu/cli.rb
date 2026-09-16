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
    COLORS = {
      header: "1;35",
      note: "33",
      bold: "1",
      dim: "2",
      error: "31"
    }.freeze

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
      else
        # Anything else is either a mayu-build command or a typo, and the fix
        # for both starts with installing mayu-build. Keeping no list of its
        # commands here means nothing to update when it grows one.
        output.puts missing_build_gem_message(command)
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
        #{color(:header, "Mayu v#{Mayu::VERSION}")}

        Usage: #{color(:bold, "mayu start")} #{color(:dim, "[--filename <path>] [--assets-dir <path>] [--source-root <path>]")}

        #{color(:note, "Only the production server is available.")}
        Install the #{color(:bold, "mayu-build")} gem for the development commands.
      USAGE
    end

    # mayu-build depends on mayu-live at exactly the same version, so the
    # suggestion pins it rather than using a pessimistic constraint.
    def self.missing_build_gem_message(command)
      version = Mayu::VERSION

      <<~MESSAGE
        #{color(:error, "#{color(:bold, "mayu #{command}")} is not available.")}

        Only #{color(:bold, "mayu start")} works without the #{color(:bold, "mayu-build")} gem.

        Add it next to mayu-live in your Gemfile:

        #{color(:dim, "group :development, :test do")}
          #{color(:bold, "gem \"mayu-build\", \"= #{version}\"")}
        #{color(:dim, "end")}
      MESSAGE
    end

    # Honors NO_COLOR (https://no-color.org): any non-empty value turns
    # colors off.
    def self.color(name, text)
      return text.to_s unless ENV["NO_COLOR"].to_s.empty?

      "\e[#{COLORS.fetch(name)}m#{text}\e[0m"
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
      output.puts color(:error, error.message)
      output.puts parser
      1
    end

    # Starts the production server. Shared with mayu-build's `start` command so
    # both entry points behave the same.
    def self.start(filename:, assets_dir:, source_root:, output: $stdout)
      unless File.exist?(filename)
        output.puts color(:error, "Could not find #{color(:bold, filename)}")
        output.puts "Try #{color(:bold, "bundle exec mayu build")} to build the app."
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
          output.puts color(:bold, "#{const_name} is enabled!")
        else
          output.puts color(:dim, "#{const_name} is disabled!")
        end
      else
        output.puts color(:dim, "#{const_name} is not supported")
      end
    end

    private_class_method :start_from_argv, :print_jit_message
  end
end
