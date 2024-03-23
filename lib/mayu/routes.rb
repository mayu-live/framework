# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "rack/utils"
require "pathname"

module Mayu
  module Routes
    Segment =
      Data.define(:name, :views, :children) do
        def regexp = Regexp.escape(name)
        def pathname(params) = name
      end

    Group =
      Data.define(:name, :views, :children) do
        def regexp = nil
        def pathname(params) = nil
      end

    Param =
      Data.define(:name, :param, :views, :children) do
        def regexp = "(?<#{Regexp.escape(param)}>[^\/]+)"
        def pathname(params) = params.fetch(param)
      end

    SplatParam =
      Data.define(:name, :param, :views) do
        def self.[](name, param, views, children)
          raise "Splat param must be last" unless children.empty?

          new(name, param, views)
        end
        def regexp = "(?<#{Regexp.escape(param)}>.+)"
        def pathname(params) = Array(params.fetch(param)).join("/")
        def children = []
      end

    Root =
      Data.define(:path, :views, :children) do
        def regexp = nil
        def pathname(params) = ""
      end

    Views = Data.define(:page, :layout, :template, :not_found)

    Match = Data.define(:route, :params, :query)

    module Utils
      def self.parse_query(query)
        query
          .then { Rack::Utils.parse_nested_query(_1) }
          .then { deep_symbolize_keys(_1) }
      end

      def self.deep_symbolize_keys(obj)
        case obj
        when Hash
          obj
            .transform_keys do |key|
              case key
              in /\A[[:digit:]+]\z/
                key.to_i
              in String
                key.to_sym
              else
                key
              end
            end
            .transform_values do |value|
              deep_symbolize_keys(value)
            end
        else
          obj
        end
      end
    end

    Route =
      Data.define(:regexp, :segments, :views, :layouts) do
        def match(request_path)
          path, query = request_path.split("?", 2)

          if match = regexp.match(path)
            Match[
              self,
              match
                .named_captures
                .transform_keys(&:to_sym)
                .transform_values do
                  case _1.split("/")
                  in [one]
                    one
                  in many
                    many
                  end
                end,
              Utils.parse_query(query)
            ]
          end
        end

        def pathname(**params)
          segments.map { _1.pathname(params) }.compact.join("/")
        end
      end

    Router =
      Data.define(:root_dir, :routes) do
        def self.build(root_dir)
          new(root_dir, Builder.build(root_dir))
        end

        def match(path)
          routes.each do |route|
            if match = route.match(path)
              return match
            end
          end

          nil
        end

        def all_templates
          set = Set.new

          routes.each do |route|
            set.add(route.views.page)
            route.layouts.each do |layout|
              set.add(layout)
            end
          end

          set
        end
      end

    class Builder
      def self.build(root_dir)
        new(root_dir).build
      end

      def initialize(root_dir)
        @root_dir = root_dir
      end

      def build
        root =
          Root.new(
            @root_dir,
            build_page(@root_dir),
            traverse_children(@root_dir)
          )

        routes = []

        build_routes(root) { |route| routes << route if route.views.page }

        routes
      end

      def build_routes(node, parents = [], &block)
        segments = [*parents, node].compact

        yield(
          Route[
            Regexp.compile(
              '\A/' + segments.map(&:regexp).compact.join('\/') + '\z'
            ),
            segments,
            node.views,
            segments.map(&:views).map(&:layout).compact
          ]
        )

        node.children.each { |child| build_routes(child, segments, &block) }
      end

      def build_page(dir)
        views = { page: nil, layout: nil, template: nil, not_found: nil }

        Dir
          .entries(dir)
          .map do |entry|
            path =
              Pathname
                .new(File.join(dir, entry))
                .relative_path_from(@root_dir)
                .to_s

            case entry
            in "page.haml"
              views[:page] = path
            in "layout.haml"
              views[:layout] = path
            in "template.haml"
              views[:template] = path
            in "not-found.haml"
              views[:not_found] = path
            else
              nil
            end
          end

        Views.new(**views)
      end

      def traverse_children(dir)
        Dir
          .each_child(dir)
          .map do |entry|
            path = File.join(dir, entry)

            if File.directory?(path)
              case entry
              in /\A\::(.*)\Z/ # [param]
                SplatParam[
                  entry,
                  $~[1],
                  build_page(path),
                  traverse_children(path)
                ]
              in /\A\:(.*)\Z/ # [param]
                Param[entry, $~[1], build_page(path), traverse_children(path)]
              in /\A\((.*)\)\Z/ # (group)
                Group[entry, build_page(path), traverse_children(path)]
              else
                Segment[entry, build_page(path), traverse_children(path)]
              end
            end
          end
          .compact
      end
    end
  end
end
