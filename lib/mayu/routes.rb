# typed: strict

require "terminal-table"

module Mayu
  module Routes
    extend T::Sig

    class NotFoundError < StandardError
    end

    class Route < T::Struct
      const :path, String
      const :regexp, Regexp
      const :layouts, T::Array[String]
      const :template, String
    end

    class RouteMatch < T::Struct
      const :params, T::Hash[Symbol, String]
      const :layouts, T::Array[String]
      const :template, String
    end

    EXTENSIONS = T.let(%w[.rb .rux .haml].freeze, T::Array[String])

    PAGE_FILENAME = "page"
    LAYOUT_FILENAME = "layout"
    NOT_FOUND_FILENAME = "404"

    sig do
      params(
        root: String,
        routes: T::Array[Route],
        layouts: T::Array[String],
        path: T::Array[String],
        level: Integer
      ).returns(T::Array[Route])
    end
    def self.build_routes(root, routes: [], layouts: [], path: [], level: 0)
      dir = T.unsafe(File).join(root, *path)
      return routes unless File.directory?(dir)

      entries = Dir.entries(dir) - %w[. ..]

      if layout = find_and_delete(entries, LAYOUT_FILENAME)
        layouts += [T.unsafe(File).join(*path, layout)]
      end

      if page = find_and_delete(entries, PAGE_FILENAME)
        routes.push(
          Route.new(
            path: path.join("/"),
            regexp: path_to_regexp(path.join("/")),
            layouts:,
            template: T.unsafe(File).join(*path, page)
          )
        )
      end

      entries.each do |entry|
        build_routes(
          File.join(root),
          routes:,
          layouts:,
          path: path + [entry],
          level: level.succ
        )
      end

      if not_found = find_and_delete(entries, NOT_FOUND_FILENAME)
        routes.push(
          Route.new(
            path: path.join("/"),
            regexp: path_to_regexp([*path, "*"].join("/")),
            layouts:,
            template: T.unsafe(File).join(*path, not_found)
          )
        )
      else
        Console.logger.warn(self) { <<~EOF } if level.zero?
            There is no #{NOT_FOUND_FILENAME} in the app root,
            you should probably create one.
            EOF
      end

      routes
    end

    sig { params(routes: T::Array[Route]).void }
    def self.log_routes(routes)
      Console
        .logger
        .info(self) do
          Terminal::Table.new do |t|
            t.headings =
              %w[Path Template Layouts Regexp].map { "\e[1m#{_1}\e[0m" }
            t.style = { all_separators: true, border: :unicode }

            routes.each do |route|
              t.add_row(
                [
                  "/#{route.path}",
                  route.template,
                  route.layouts.join("\n"),
                  "/#{route.regexp.to_s}/"
                ]
              )
            end
          end
        end
    end

    sig do
      params(routes: T::Array[Route], request_path: String).returns(RouteMatch)
    end
    def self.match_route(routes, request_path)
      routes.each do |route|
        match = route.regexp.match(request_path)

        next unless match

        return(
          RouteMatch.new(
            template: route.template,
            layouts: route.layouts,
            params:
              match
                .named_captures
                .transform_keys(&:to_sym)
                .transform_values(&:to_s)
          )
        )
      end

      raise NotFoundError,
            "Page not found, and no 404 page either. You should probably create one."
    end

    sig do
      params(path: String, formats: T::Hash[Symbol, Regexp]).returns(Regexp)
    end
    def self.path_to_regexp(path, formats: {})
      parts =
        path
          .delete_prefix("/")
          .split("/")
          .map do |part|
            case part
            when "*"
              ".+"
            when /\A:(?<var>\w+)\Z/
              var = Regexp.escape($~[:var])
              "(?<#{var}>[^/]+)"
            else
              Regexp.escape(part).to_s
            end
          end

      Regexp.new('\A\/' + parts.join('\/') + '\Z')
    end

    sig { params(a: T::Array[String], name: String).returns(T.nilable(String)) }
    def self.find_and_delete(a, name)
      EXTENSIONS.find do |extension|
        a.delete("#{name}#{extension}")&.tap { return _1 }
      end
    end
  end
end
