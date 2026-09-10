# frozen_string_literal: true

module Mayu
  module Commands
    class Routes < Samovar::Command
      HTTP_METHODS = %w[GET POST PUT PATCH DELETE OPTIONS HEAD].freeze
      TREE_INDENT = "   "
      COLORS = {
        reset: "\e[0m",
        heading: "\e[1;34m",
        method: "\e[1;32m",
        path: "\e[1;36m",
        type: "\e[1;35m",
        layout: "\e[33m",
        source: "\e[2m",
        slot: "\e[35m"
      }.freeze

      self.description = "Print routes"
      options { option "--regexp", "Include regexp patterns", default: false }

      def call
        require_relative "../configuration"
        require_relative "../klenod"

        Configuration.with(:development) do |config|
          configuration = Klenod::Configuration.load(root: config.root)
          @context = configuration.context
          @include_regexp = options[:regexp]

          print_table(route_rows(configuration.route_manifest))
          print_route_tree(configuration.route_manifest)
        end
      end

      private

      attr_reader :context

      def color(name, value)
        return value if ENV.key?("NO_COLOR")

        "#{COLORS.fetch(name)}#{value}#{COLORS.fetch(:reset)}"
      end

      def route_rows(manifest)
        [
          *manifest.routes.flat_map { route_rows_for(it) },
          *manifest.special_views.map { ["-", it.path, it.kind.to_s, module_path(it.view_module_id), it] }
        ]
      end

      def route_rows_for(route)
        rows = []
        if route.page_module_id
          rows << ["GET", route.path, route.slot_layout_module_id ? "slot" : "page", module_path(route.page_module_id), route]
        end
        return rows unless route.handler_module_id

        methods = route_methods(route.handler_module_id)
        methods = ["-"] if methods.empty?
        rows.concat(methods.map { |method| [method, route.path, "handler", module_path(route.handler_module_id), route] })
      end

      def print_table(rows)
        columns = ["METHOD", "PATH", "TYPE", "SOURCE"]
        columns.insert(2, "REGEXP") if @include_regexp
        values =
          rows.map do |method, path, type, source, route|
            [method, path, (route_regexp(route).inspect if @include_regexp), type, source].compact
          end
        widths = columns.each_index.map { |index| ([columns[index]] + values.map { it.fetch(index) }).map(&:length).max }

        puts format_table_row(columns, widths, columns:)
        puts widths.map { "-" * it }.join("  ")
        values.each do |row|
          puts format_table_row(row, widths, columns:)
        end
      end

      def format_table_row(row, widths, columns:)
        row
          .each_with_index
          .map do |value, index|
            padded = value.ljust(widths.fetch(index))
            color(table_color(columns.fetch(index)), padded)
          end
          .join("  ")
      end

      def table_color(column)
        {
          "METHOD" => :method,
          "PATH" => :path,
          "REGEXP" => :source,
          "TYPE" => :type,
          "SOURCE" => :source
        }.fetch(column, :heading)
      end

      def print_route_tree(manifest)
        puts
        puts color(:heading, "Route tree")

        route_groups(manifest.routes).each do |_path, routes|
          primary = routes.find { it.slot_layout_module_id.nil? } || routes.fetch(0)
          slots = routes.select(&:slot_layout_module_id).sort_by { slot_name(it) }

          puts
          puts route_heading(primary)
          print_layout_tree(primary, slots)
        end

        print_special_views(manifest.special_views)
      end

      def print_special_views(views)
        return if views.empty?

        puts
        puts color(:heading, "Special views")
        views.each do |view|
          puts
          puts "#{color(:type, view.kind)} #{color(:path, view.path)}"
          print_layout_tree(view, [])
        end
      end

      def route_groups(routes)
        routes.group_by(&:path).sort_by do |path, grouped_routes|
          primary = grouped_routes.find { it.slot_layout_module_id.nil? } || grouped_routes.fetch(0)
          [path.split("/").length, path, route_type(primary)]
        end
      end

      def print_layout_tree(route, slots)
        leaves = [*route_leaves(route), *slots.map { slot_leaf(it) }]
        layout_ids = route.layout_module_ids
        return print_leaf_group(leaves, "") if layout_ids.empty?

        layout_ids.each_with_index do |layout_id, index|
          puts "#{tree_prefix(index)}└─ #{color(:layout, "layout")} #{color(:source, module_path(layout_id))}"
          next unless index == layout_ids.length - 1

          print_leaf_group(leaves.select { it.fetch(:layout_id) == layout_id }, tree_prefix(index + 1))
        end
      end

      def route_leaves(route)
        leaves = []
        if route.respond_to?(:page_module_id) && route.page_module_id
          leaves << {layout_id: route.layout_module_ids.last, label: color(:type, "page"), source: module_path(route.page_module_id)}
        end
        if route.respond_to?(:handler_module_id) && route.handler_module_id
          leaves << {layout_id: route.layout_module_ids.last, label: color(:type, "handler"), source: source_for_handler(route)}
        end
        if route.respond_to?(:view_module_id)
          leaves << {layout_id: route.layout_module_ids.last, label: color(:type, route.kind), source: module_path(route.view_module_id)}
        end
        leaves
      end

      def slot_leaf(route)
        {layout_id: route.slot_layout_module_id, label: color(:slot, "slot @#{slot_name(route)}"), source: module_path(route.page_module_id)}
      end

      def print_leaf_group(leaves, prefix)
        leaves.each { |leaf| puts "#{prefix}#{leaf.fetch(:label)} #{color(:source, leaf.fetch(:source))}" }
      end

      def route_heading(route)
        "#{color(:method, route_methods_for_display(route).join(","))} #{color(:path, route.path)} #{color(:type, "(#{route_type(route)})")}"
      end

      def route_methods_for_display(route)
        methods = []
        methods << "GET" if route.page_module_id
        if route.handler_module_id
          handler_methods = route_methods(route.handler_module_id)
          methods.concat(handler_methods.empty? ? ["-"] : handler_methods)
        end
        methods.uniq
      end

      def route_methods(module_id)
        return [] unless module_id

        source_path = context.graph.absolute_path(module_id)
        return [] unless File.file?(source_path)

        File.read(source_path).scan(/^\s*def\s+(#{HTTP_METHODS.join("|")})\b/).flatten
      end

      def source_for_handler(route)
        source_path = context.graph.absolute_path(route.handler_module_id)
        line = File.readlines(source_path).find_index { |source| source.match?(/^\s*def\s+(#{HTTP_METHODS.join("|")})\b/) }
        line ? "#{module_path(route.handler_module_id)}:#{line + 1}" : module_path(route.handler_module_id)
      end

      def route_type(route)
        return "slot" if route.slot_layout_module_id
        return "page+handler" if route.page_module_id && route.handler_module_id
        return "handler" unless route.page_module_id

        "page"
      end

      def route_regexp(route)
        pattern =
          route.segments.filter_map do |segment|
            case segment.kind
            when :static, :intercept_current, :intercept_parent, :intercept_root then Regexp.escape(segment.path_part)
            when :dynamic then "(?<#{segment.param_name}>[^/]+)"
            when :catch_all, :optional_catch_all then "(?<#{segment.param_name}>.*)"
            end
          end.join("/")
        Regexp.new("\\A/#{pattern}\\z")
      end

      def slot_name(route) = route.segments.find { it.kind == :parallel }&.param_name || "default"
      def tree_prefix(depth) = TREE_INDENT * depth
      def module_path(module_id) = module_id&.path.to_s
    end
  end
end
