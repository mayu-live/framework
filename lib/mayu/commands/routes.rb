# frozen_string_literal: true

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
        require_relative "../configuration"
        require_relative "../klenod"

        Configuration.with(:development) do |config|
          manifest =
            Klenod::Configuration.load(root: config.root).route_manifest

          table =
            Terminal::Table.new do |table|
              table.style = { all_separators: true, border: :unicode }
              table.headings =
                [
                  "Path",
                  ("Regexp" if @options[:regexp]),
                  "Kind",
                  "Page",
                  "Handler",
                  "Layouts"
                ].compact.map { "\e[1m#{it}\e[0m" }
              manifest.routes.each do |route|
                add_route_row(table, route, route.page_module_id)
              end
              manifest.special_views.each do |view|
                add_route_row(table, view, view.view_module_id)
              end
            end
          puts table
        end
      end

      private

      def add_route_row(table, route, page_module_id)
        table.add_row(
          [
            format_segments(route.segments).then do
              it.empty? ? FORMATTED_SLASH : it
            end,
            (route_regexp(route).inspect if @options[:regexp]),
            route.kind,
            module_path(page_module_id),
            module_path(
              (
                if route.respond_to?(:handler_module_id)
                  route.handler_module_id
                else
                  nil
                end
              )
            ),
            route.layout_module_ids.map { module_path(it) }.join("\n")
          ].compact
        )
      end

      def format_segments(segments)
        segments
          .filter_map do |segment|
            case segment.kind
            when :dynamic
              format(PARAM_FORMAT, ":#{segment.param_name}")
            when :catch_all, :optional_catch_all
              format(SPLAT_PARAM_FORMAT, "*#{segment.param_name}")
            when :group, :parallel
              nil
            else
              segment.path_part
            end
          end
          .join(FORMATTED_SLASH)
      end

      def route_regexp(route)
        pattern =
          route
            .segments
            .filter_map do |segment|
              case segment.kind
              when :static, :intercept_current, :intercept_parent,
                   :intercept_root
                Regexp.escape(segment.path_part)
              when :dynamic
                "(?<#{segment.param_name}>[^/]+)"
              when :catch_all, :optional_catch_all
                "(?<#{segment.param_name}>.*)"
              end
            end
            .join("/")
        Regexp.new("\\A/#{pattern}\\z")
      end

      def module_path(module_id) = module_id&.path.to_s
    end
  end
end
