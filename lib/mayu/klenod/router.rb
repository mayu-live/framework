# frozen_string_literal: true

require "uri"

module Mayu
  module Klenod
    class Router
      ResolvedPage =
        Data.define(:descriptor, :status, :module_ids, :stylesheets, :scripts)

      def initialize(
        provider,
        root_entry: "root.haml",
        router_entry: "virtual:router"
      )
        @provider = provider
        @root_entry = root_entry
        @router_entry = router_entry
      end

      def descriptor_for(path) = resolve(path)&.descriptor

      def resolve(path)
        uri = URI.parse(path)
        match = match(path) || router.not_found(uri.path)
        return unless match&.page

        page =
          Runtime::H[
            match.page,
            params: match.params,
            query: URI.decode_www_form(uri.query.to_s).to_h
          ]

        descriptor =
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

        module_ids = module_ids_for(match)
        ResolvedPage.new(
          descriptor,
          match.respond_to?(:status) ? match.status : 200,
          module_ids,
          asset_urls(module_ids, :css),
          asset_urls(module_ids, :javascript)
        )
      end

      private

      public def match(path)
        router.match(URI.parse(path).path)
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

      def module_ids_for(match)
        [
          @root_entry,
          *match.route.layout_module_ids,
          route_page_module_id(match.route)
        ].compact.map { @provider.module_id_for(it).to_s }
      end

      def asset_urls(module_ids, type)
        @provider.assets_for_module(module_ids, type:).map(&:url).uniq
      end

      def route_page_module_id(route)
        return route.page_module_id if route.respond_to?(:page_module_id)
        return route.module_id if route.respond_to?(:module_id)

        route.view_module_id
      end
    end
  end
end
