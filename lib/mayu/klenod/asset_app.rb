# frozen_string_literal: true

require "protocol/http/response"
require "klenod/rack"

module Mayu
  module Klenod
    # Adapts Klenod's Rack-independent asset response to the Async Protocol HTTP
    # response used by Mayu's server.
    class AssetApp
      def initialize(provider)
        @asset_app =
          ::Klenod::Rack::AssetApp.new(
            provider.source,
            assets_dir: provider.assets_dir,
            base: provider.asset_base
          )
      end

      def response_for(request, headers: {})
        response =
          @asset_app.response_for(
            request.path,
            "HTTP_ACCEPT_ENCODING" => request.headers["accept-encoding"].to_s
          )
        return nil unless response

        Protocol::HTTP::Response[
          response.status,
          response.headers.merge(headers),
          response.body
        ]
      end
    end
  end
end
