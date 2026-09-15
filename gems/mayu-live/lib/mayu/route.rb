# frozen_string_literal: true

require "uri"

module Mayu
  # Base class for Klenod `+route.rb` handlers. It is intentionally small: the
  # router owns matching while Mayu owns HTTP dispatch and the request wrapper.
  class Route
    Request =
      Data.define(:method, :path, :headers, :body, :params, :query) do
        def self.from_async(request, params: {})
          uri = URI.parse(request.path)
          query = URI.decode_www_form(uri.query.to_s).to_h.freeze

          new(
            method: request.method,
            path: uri.path,
            headers: request.headers.to_h.freeze,
            body: request.read,
            params: params.transform_keys(&:to_sym).freeze,
            query:
          )
        end
      end
  end
end
