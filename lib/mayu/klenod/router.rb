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
        match = match(path)
        return resolved_page_for(match, path, uri) if match

        not_found(path)
      end

      def not_found(path)
        uri = URI.parse(path)
        resolved_page_for(
          router.not_found(uri.path),
          path,
          uri,
          props: {
            path:,
            status: 404
          }
        )
      end

      def error(path, error: nil)
        uri = URI.parse(path)
        resolved_page_for(
          router.error(uri.path),
          path,
          uri,
          props: { path:, status: 500, error: }.compact
        )
      end

      private

      def resolved_page_for(match, path, uri, props: {})
        return unless match&.page
        query = URI.decode_www_form(uri.query.to_s).to_h

        page = Runtime::H[match.page, params: match.params, query:, **props]

        layouts = [
          [root_component, @root_entry],
          *match.layouts.zip(match.route.layout_module_ids)
        ]

        descriptor =
          layouts
            .reverse
            .reduce(page) do |child, (layout, module_id)|
              Runtime::H[
                layout,
                child,
                *slot_descriptors_for(match, module_id, query:),
                params: match.params,
                query:,
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

      public def match(path)
        router.match(URI.parse(path).path)
      end

      private

      def router
        # Klenod replaces the virtual router export when route files are added
        # or removed. Resolve it on demand so a long-lived Mayu adapter sees
        # the new manifest after an HMR update.
        exports_for(@router_entry)::Default
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
          route_page_module_id(match.route),
          *slot_module_ids_for(match)
        ].compact.map { @provider.module_id_for(it).to_s }
      end

      def slot_descriptors_for(match, layout_module_id, query:)
        return [] unless match.respond_to?(:slots)

        match
          .slots
          .sort_by { |name, _slot_match| name.to_s }
          .filter_map do |name, slot_match|
            next unless slot_match.layout_module_id == layout_module_id

            Runtime::H[
              slot_match.page,
              slot: name,
              params: slot_match.params,
              query:
            ]
          end
      end

      def slot_module_ids_for(match)
        return [] unless match.respond_to?(:slots)

        rendered_layout_ids = match.route.layout_module_ids

        match
          .slots
          .sort_by { |name, _slot_match| name.to_s }
          .flat_map do |_name, slot_match|
            unless rendered_layout_ids.include?(slot_match.layout_module_id)
              next []
            end

            [
              *slot_match.route.layout_module_ids,
              route_page_module_id(slot_match.route)
            ]
          end
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
