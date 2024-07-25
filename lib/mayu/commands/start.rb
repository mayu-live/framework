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

        print_yjit_message

        require_relative "../configuration"
        require_relative "../server"
        require_relative "../component"
        require_relative "../system_config"

        Sync do
          Environment.with(:production) do |environment|
            load_system.use do |system|
              Mayu::Server.new(environment).run.wait
            rescue => e
              Console.logger(self, e)
              raise
            ensure
              puts "\e[44mStopping dev\e[0m"
            end
          end
        end
      end

      private

      def print_yjit_message
        if RubyVM.const_defined?(:YJIT)
          if RubyVM::YJIT.enabled?
            puts "\e[1mYJIT is enabled!\e[0m"
          else
            puts "\e[2mYJIT is disabled!\e[0m"
          end
        else
          puts "\e[2mYJIT is not supported!\e[0m"
        end
      end

      def load_system
        options[:filename]
          .then { File.read(_1, encoding: "binary") }
          .then { Marshal.load(_1) }
      end
    end
  end
end
