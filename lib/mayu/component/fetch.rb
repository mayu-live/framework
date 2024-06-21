# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "singleton"
require "async/http/internet"
require "rack/utils"
require "uri"

module Mayu
  module Component
    class Fetch
      Response =
        Data.define(
          :url,
          :body,
          :headers,
          :status,
          :status_text,
          :ok?,
          :redirected?
        ) do
          def json(symbolize_names: false) = JSON.parse(body, symbolize_names:)

          def content_type = headers.fetch("content-type").to_s

          def inspect
            "<##{self.class.name} #{inspect_attributes}>"

            private

            def inspect_attributes
              [
                "url=#{url.inspect}",
                "status=#{status.inspect}",
                "status_text=#{status_text.inspect}",
                "content_type=#{content_type.inspect}",
                "body=#{body.bytesize}b"
              ].join(" ")
            end
          end
        end

      include Singleton

      module Helper
        def fetch(...)
          Fetch.instance.fetch(...)
        end
      end

      def initialize
        @internet = Async::HTTP::Internet.new
      end

      def fetch(url, method: :GET, headers: {}, body: nil)
        puts "\e[35mFETCHING #{url}\e[0m"
        res = @internet.call(method, url, headers.to_a, body)
        puts "\e[34mFETCHED #{url}\e[0m"

        Response.new(
          url:,
          body: res.read,
          headers: res.headers.to_h,
          status: res.status,
          status_text: Rack::Utils::HTTP_STATUS_CODES[res.status],
          ok?: res.success?,
          redirected?: res.redirection?
        )
      rescue => e
        puts "\e[32mFAILED ON #{url}\e[0m"
        raise
      end
    end
  end
end
