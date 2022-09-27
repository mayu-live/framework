# typed: strict
# frozen_string_literal: true

module Mayu
  module Routing
    class Matcher
      extend T::Sig

      class RouteError < StandardError
      end

      sig { params(root: Routes::Route).void }
      def initialize(root)
        @root = root
      end

      sig { params(path: String).void }
      def match(path)
        layouts = []
        parts = []
        params = {}

        not_found = T.let(nil, T.nilable(String))

        found =
          path
            .delete_prefix("/")
            .split("/")
            .reduce(@root) do |curr, part|
              layouts.push(File.join("", *parts, curr.layout)) if curr.layout

              if curr.not_found
                not_found = File.join("", *parts, curr.not_found)
              end

              match = curr.match(part)

              break unless match

              if match.is_a?(Routes::Param)
                params[match.name.to_sym] = part
                parts.push(":#{part}")
              else
                parts.push(part)
              end

              match
            end

        return { layouts:, component: File.join("", *parts), params: } if found

        return { layouts: [], component: not_found, params: } if not_found

        raise RouteError, "No 404 page configured, put one in #{@root}"
      end
    end
  end
end
