# frozen_string_literal: true

require_relative "../klenod"

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Start < Samovar::Command
      self.description = "Start the production server"

      options do
        option(
          "--filename <string>",
          "Filename of the generated bundle",
          default: Klenod::BUNDLE_FILENAME
        )
        option(
          "--assets-dir <path>",
          "Directory with the assets written by mayu build",
          default: Klenod::ASSETS_DIR
        )
        option(
          "--source-root <path>",
          "Directory the bundle was built from, for backtraces and source maps",
          default: Klenod::SOURCE_DIR
        )
      end

      def call
        unless File.exist?(options[:filename])
          puts "\e[31mCould not find \e[1m#{options[:filename]}\e[0m"
          puts "Try \e[1mbundle exec mayu build\e[0m to build the app."
          exit 1
        end

        print_jit_message(:YJIT)
        print_jit_message(:ZJIT)

        require_relative "../configuration"
        require_relative "../server"

        Configuration.with(:production) do |config|
          bundle_path = File.expand_path(options[:filename])
          assets_dir = File.expand_path(options[:assets_dir])
          source_root = File.expand_path(options[:source_root])

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
      rescue Interrupt
      end

      private

      def print_jit_message(const_name)
        if RubyVM.const_defined?(const_name)
          if RubyVM.const_get(const_name).enabled?
            puts "\e[1m#{const_name} is enabled!\e[0m"
          else
            puts "\e[2m#{const_name} is disabled!\e[0m"
          end
        else
          puts "\e[2m#{const_name} is not supported\e[0m"
        end
      end
    end
  end
end
