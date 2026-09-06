# frozen_string_literal: true

require "uri"

module Mayu
  module Klenod
    class Router
      def initialize(
        provider,
        root_entry: "root.haml",
        router_entry: "virtual:router"
      )
        @provider = provider
        @root_entry = root_entry
        @router_entry = router_entry
      end

      def descriptor_for(path)
        uri = URI.parse(path)
        match = router.match(uri.path)
        return unless match&.page

        page =
          Runtime::H[
            match.page,
            params: match.params,
            query: URI.decode_www_form(uri.query.to_s).to_h
          ]

        [root_component, *match.layouts].reverse
          .reduce(page) do |child, layout|
            Runtime::H[
              layout,
              child,
              params: match.params,
              query: URI.decode_www_form(uri.query.to_s).to_h,
              path:
            ]
          end
      end

      private

      def router
        @router ||= exports_for(@router_entry)::Default
      end

      def root_component
        @root_component ||= exports_for(@root_entry)::Default
      end

      def exports_for(entry)
        @provider.exports(@provider.entry(entry))
      end
    end
  end
end
