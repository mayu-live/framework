# typed: strict

module Mayu
  module Routes
    extend T::Sig

    PAGE_FILENAME = "page.mayu"
    LAYOUT_FILENAME = "layout.mayu"
    NOT_FOUND_FILENAME = "404.mayu"

    class NotFoundError < StandardError ; end

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

    sig{params(root: String, routes: T::Array[Route], layouts: T::Array[String], path: T::Array[String], level: Integer).returns(T::Array[Route])}
    def self.build_routes(root, routes: [], layouts:  [], path: [], level: 0)
      dir = T.unsafe(File).join(root, *path)
      return routes unless File.directory?(dir)

      dirname = File.basename(dir)
      entries = Dir.entries(dir) - %w(. ..)

      if layout = entries.delete(LAYOUT_FILENAME)
        layouts += [T.unsafe(File).join(*path, layout)]
      end

      if page = entries.delete(PAGE_FILENAME)
        routes.push(Route.new(
          path: path.join('/'),
          regexp: path_to_regexp(path.join('/')),
          layouts:,
          template: T.unsafe(File).join(*path, page)
        ))
      end

      entries.each do |entry|
        build_routes(File.join(root, entry),
          routes:,
          layouts:,
          path: path + [dirname],
          level: level.succ,
        )
      end

      if not_found = entries.delete(NOT_FOUND_FILENAME)
        routes.push(Route.new({
          path: path.join('/'),
          regexp: path_to_regexp(path.concat(["[...anything]"]).join('/')),
          layouts:,
          template: T.unsafe(File).join(*path, not_found)
        }))
      else
        if level.zero?
          Console.logger.warn(self) {
            <<~EOF
            There is no #{NOT_FOUND_FILENAME} in the app root,
            you should probably create one.
            EOF
          }
        end
      end

      routes
    end

    sig {params(routes: T::Array[Route], request_path: String).returns(RouteMatch)}
    def self.match_route(routes, request_path)
      routes.each do |route|
        match = route.regexp.match(request_path)

        next unless match

        return RouteMatch.new(
          template: route.template,
          layouts: route.layouts,
          params: match.named_captures
            .transform_keys(&:to_sym)
            .transform_values(&:to_s)
        )
      end

      raise NotFoundError,
        "Page not found, and no 404 page either. You should probably create one."
    end

    sig {params(path: String).returns(Regexp)}
    def self.path_to_regexp(path)
      parts = path.split('/').map do |part|
        if part.match(/\A\[(?<var>\w+)\]\Z/)
          var = Regexp.escape($~[:var])
          "(?<#{var}>[^/]+)"
        else
          Regexp.escape(part).to_s
        end
      end

      Regexp.new('\A\/' + parts.join('\/') + '\Z')
    end
    #
    # PAGES_ROOT = File.join(File.dirname(__FILE__), "example", "pages")
    #
    # routes = build_routes(PAGES_ROOT)
    #
    # p match_route(routes, "/items/123")
  end
end
