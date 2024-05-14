# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Commands
    class Routes < Samovar::Command
      self.description = "Print routes"

      options { option "--regexp", "Include regexp patterns", default: false }

      def call
        require "terminal-table"
        require_relative "../configuration"
        require_relative "../environment"
        require_relative "../routes"

        Mayu::Configuration.with do |config|
          config = config.fetch(:dev)

          environment = Mayu::Environment.from_config(config)

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
                    case route.segments.join("/")
                    in ""
                      "/"
                    in path
                      path
                    end,
                    (route.regexp.inspect if @options[:regexp]),
                    Pathname.new(
                      File.join(environment.pages_dir, route.views.page)
                    ).relative_path_from(config.root),
                    route
                      .layouts
                      .map do |layout|
                        Pathname.new(
                          File.join(environment.pages_dir, layout)
                        ).relative_path_from(config.root)
                      end
                      .join("\n")
                  ].compact
                )
              end
            end
          )
        end
      end
    end
  end
end
