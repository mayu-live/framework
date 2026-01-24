# frozen_string_literal: true
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
          default: "app.mayu-bundle"
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

        require "dotenv/load"

        require_relative "../configuration"
        require_relative "../server"
        require_relative "../component"
        require_relative "../system_config"

        Sync do
          load_environment do |environment|
            Console.logger.info(self, "Starting server")
            Mayu::Server.new(environment).run.wait
          rescue => e
            Console.logger(self, e)
            raise
          end
        end
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

      def load_environment
        dumped = File.read(options[:filename], encoding: "binary")

        Environment.load(:production, dumped) do |environment|
          yield environment
        end
      end
    end
  end
end
