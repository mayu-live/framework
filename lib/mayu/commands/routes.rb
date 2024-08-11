# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Routes < Samovar::Command
      RESET = "\e[0m"
      FORMATTED_SLASH = "\e[2m/#{RESET}"
      PARAM_FORMAT = "\e[1;34m%s#{RESET}"
      SPLAT_PARAM_FORMAT = "\e[1;33m%s#{RESET}"

      self.description = "Print routes"

      options { option "--regexp", "Include regexp patterns", default: false }

      def call
        require "terminal-table"
        require_relative "../environment"
        require_relative "../routes"

        Configuration.with(:development) do |config|
          environment = Environment.new(config)

          puts(
            Terminal::Table.new do |t|
              t.style = { all_separators: true, border: :unicode }
              t.headings =
                [
                  "Path",
                  ("Regexp" if @options[:regexp]),
                  "Page",
                  "Layouts"
                ].compact.map { "\e[1m#{_1}\e[0m" }

              environment.router.routes.each do |route|
                t.add_row(
                  [
                    case format_segments(route.segments)
                    in ""
                      FORMATTED_SLASH
                    in path
                      path
                    end,
                    (route.regexp.inspect if @options[:regexp]),
                    Pathname.new(
                      File.join(environment.pages_dir, route.views.page)
                    ).relative_path_from(environment.config.root),
                    route
                      .layouts
                      .map do |layout|
                        Pathname.new(
                          File.join(environment.pages_dir, layout)
                        ).relative_path_from(environment.config.root)
                      end
                      .join("\n")
                  ].compact
                )
              end
            end
          )
        end
      end

      private

      def format_segments(segments)
        segments
          .map do |segment|
            case segment
            in Mayu::Routes::Param
              format(PARAM_FORMAT, segment)
            in Mayu::Routes::SplatParam
              format(SPLAT_PARAM_FORMAT, segment)
            in Mayu::Routes::Group
              nil
            else
              segment
            end
          end
          .compact
          .join(FORMATTED_SLASH)
      end
    end
  end
end
