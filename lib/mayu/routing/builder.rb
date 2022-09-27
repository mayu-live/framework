# typed: strict
# frozen_string_literal: true

module Mayu
  module Routing
    class Builder
      extend T::Sig

      IGNORE = T.let(%w[. ..].freeze, T::Array[String])
      EXTENSIONS = T.let(%w[.rb .rux].freeze, T::Array[String])

      sig { params(root: String).returns(Routes::Route) }
      def self.build(root)
        new(root).build
      end

      sig { params(root: String).void }
      def initialize(root)
        @root = T.let(File.expand_path(root), String)
      end

      sig { returns(Routes::Route) }
      def build
        traverse_directory(Routes::Route.new, path: [])
      end

      private

      sig do
        params(route: Routes::Route, path: T::Array[String]).returns(
          Routes::Route
        )
      end
      def visit(route, path: [])
        absolute_path = File.join(@root, path)
        basename = File.basename(absolute_path)
        stat = File.stat(absolute_path)

        case
        when stat.directory?
          visit_dir(route, path:)
        when stat.file?
          visit_file(route, path:)
        end

        route
      end

      sig do
        params(route: Routes::Route, path: T::Array[String]).returns(
          Routes::Route
        )
      end
      def visit_dir(route, path: [])
        if match = path.last.to_s.match(/\A:(\w+)\z/)
          route.add_route(
            traverse_directory(Routes::Param.new(match[1].to_s), path:)
          )
        else
          route.add_route(
            traverse_directory(Routes::Named.new(path.last.to_s), path:)
          )
        end

        route
      end

      sig do
        params(route: Routes::Route, path: T::Array[String]).returns(
          Routes::Route
        )
      end
      def traverse_directory(route, path: [])
        absolute_path = File.join(@root, path)

        Dir
          .entries(absolute_path)
          .difference(IGNORE)
          .each { |entry| visit(route, path: [*path, entry]) }

        route
      end

      sig do
        params(route: Routes::Route, path: T::Array[String]).returns(
          Routes::Route
        )
      end
      def visit_file(route, path: [])
        basename = path.last.to_s
        extname = File.extname(basename)

        if EXTENSIONS.include?(extname)
          case basename.delete_suffix(extname)
          when "page"
            route.page = basename
          when "layout"
            route.layout = basename
          when "404"
            route.not_found = basename
          end
        end

        route
      end
    end
  end
end
