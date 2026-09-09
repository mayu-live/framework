# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Init < Samovar::Command
      NewAppConfig = Data.define(:name, :path, :fly_region, :enable_yjit)

      self.description = "Initialize a new Mayu app"

      options do
        option("--name <string>", "Application name")

        option(
          "--fly-region <string>",
          "Primary fly.io region, https://fly.io/docs/reference/regions/#fly-io-regions"
        )
      end

      def call
        require "reline"
        require "fileutils"
        require "json"

        name = read_app_name
        fly_region = read_fly_region(options[:fly_region])

        config =
          NewAppConfig.new(
            name:,
            path: File.expand_path(name),
            fly_region:,
            enable_yjit: true
          )

        if File.exist?(config.path)
          puts "\e[31mPath already exists: #{config.path}\e[0m"
          return
        end

        puts "",
          "\e[34mInitializing \e[1m#{config.name}\e[22m at \e[1m#{config.path}\e[0m"

        FileUtils.cp_r(File.join(__dir__, "init", "template"), config.path)

        Dir.chdir(config.path) do
          update_fly_toml(config)

          hide_cursor do
            print "\e[33mInstalling dependencies\e[0m"

            if system("bundle install > /dev/null")
              puts "\e[G\e[2K\e[32mInstalling dependencies ✅\e[0m"
            else
              puts "\e[G\e[2K\e[31;1mbundle install\e[22m failed, please try manually!\e[0m"
            end
          end
        end

        puts "",
          "\e[32mInitialized \e[1m#{config.name}\e[22m at \e[1m#{config.path}\e[0m"
      end

      private

      def read_app_name(name = options[:name])
        name = ask("App name:") until valid_app_name?(name)

        name
      end

      def valid_app_name?(name)
        name in /\A[a-z][a-z0-9_-]*\z/i
      end

      def read_fly_region(fly_region = options[:fly_region])
        fly_regions = load_fly_regions

        until valid_fly_region?(fly_regions, fly_region)
          begin
            if fly_regions
              Reline.autocompletion = true
              Reline.completion_proc = ->(word) do
                fly_regions.map { it["Code"] }.select { it.start_with?(word) }
              end
            end

            fly_region = ask("Fly.io primary region:")
          ensure
            Reline.completion_proc = nil
            Reline.autocompletion = false
          end
        end

        fly_region
      end

      def load_fly_regions
        JSON.parse(`flyctl platform regions --json`)
      rescue Errno::ENOENT
        warn "\e[31mCould not find flyctl executable\e[0m"
        nil
      end

      def valid_fly_region?(fly_regions, region)
        if fly_regions
          fly_regions.any? { it["Code"] == region }
        else
          region in /\A[a-z]{3}\z/
        end
      end

      def ask(question)
        Reline.readline("\e[1m#{question}\e[0m ", false)
      end

      def update_fly_toml(config)
        File
          .read("fly.toml")
          .sub(/^app\s*=.*/, "app = \"#{config.name}\"")
          .sub(
            /^primary_region\s*=.*/,
            "primary_region = \"#{config.fly_region}\""
          )
          .sub(/^(\s+ENABLE_YJIT)\s*=.*/) do
            "#{$1} = #{config.enable_yjit.to_s.inspect}"
          end
          .then { File.write("fly.toml", it) }
      end

      def hide_cursor(&)
        $stdin.echo = false
        print "\e[?25l"
        yield
      ensure
        print "\e[?25h"
        $stdin.echo = true
      end
    end
  end
end
