# typed: strict
# frozen_string_literal: true

require "reline"
require "shellwords"
require_relative "base"
require_relative "../environment"

module Mayu
  module Commands
    class Init < Base
      class NewAppConfig < T::Struct
        extend T::Sig

        const :name, String
        const :path, String
        const :primary_region, String
        const :enable_yjit, T::Boolean
      end

      extend T::Sig

      sig { void }
      def initialize
      end

      sig { params(argv: T::Array[String]).void }
      def call(argv)
        app_name = T.let(argv.first.to_s, String)

        app_name = read_app_name unless valid_app_name?(app_name)

        if File.exist?(app_name)
          puts "#{app_name} already exists"
          exit 1
        end

        config =
          NewAppConfig.new(
            path: File.join(Dir.pwd, app_name),
            name: app_name,
            primary_region: read_region,
            enable_yjit: read_boolean("Do you want to enable yjit?")
          )

        puts "\nInitializing #{config.name}"

        FileUtils.cp_r(File.join(__dir__, "init", "template"), config.path)
        update_fly_toml(config)

        puts "Installing dependencies"
        system("bundle install > /dev/null")

        puts "\n\e[32mSuccess!\e[0m Created \e[1m#{config.name}\e[0m at \e[1m#{config.path}\e[0m"
      end

      private

      sig { params(config: NewAppConfig).void }
      def update_fly_toml(config)
        Dir.chdir(config.path) do
          File.write(
            "fly.toml",
            File
              .read("fly.toml")
              .sub(/^app\s*=.*/, "app = \"#{config.name}\"")
              .sub(
                /^primary_region\s*=.*/,
                "primary_region = \"#{config.primary_region}\""
              )
              .sub(/^(\s+ENABLE_YJIT)\s*=.*/) do
                "#{$1} = #{config.enable_yjit.to_s.inspect}"
              end
          )
        end
      end

      sig { params(app_name: String).returns(T::Boolean) }
      def valid_app_name?(app_name)
        app_name in /\A[a-z][a-z0-9_-]+\z/
      end

      sig { returns(String) }
      def read_app_name
        loop do
          app_name = readline("What is your app called?")
          return app_name if valid_app_name?(app_name)
          puts "app name needs to start with a letter and only include \e[1ma-z 0-9 - _\e[0m"
        end
      end

      sig { returns(String) }
      def read_region
        puts
        puts "See all valid regions with \e[1;34mfly platform regions\e[0m"

        loop do
          region = readline("In what region do you want to deploy your app?")
          return region if region in /\A[a-z]{3}\z/
          puts "\nregion is a 3 letter code, see them with \e[1;34mfly platform regions\e[0m"
        end
      end

      sig { params(question: String).returns(String) }
      def readline(question)
        Reline.readline("\e[1m#{question}\e[0m ", false)
      end

      sig { params(question: String).returns(T::Boolean) }
      def read_boolean(question)
        loop do
          case readline("#{question} [y/n]").downcase
          in /\Ay/
            return true
          in /\An/
            return false
          end
        end
      end
    end
  end
end
