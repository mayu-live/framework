# typed: strict

require "bundler/setup"
require "sorbet-runtime"
require "async"
require "async/http/internet"
require "rack/utils"
require "pry"
require "uri"

module Mayu
  class Fetch
    class Response < T::Struct
      extend T::Sig

      const :url, String
      const :body, String
      const :headers, T::Hash[String, T.any(String, T::Array[String])]
      const :status, Integer
      const :status_text, String
      const :ok, T::Boolean
      const :redirected, T::Boolean

      alias ok? ok
      alias redirected? redirected

      sig { params(symbolize_names: T::Boolean).returns(T.untyped) }
      def json(symbolize_names: false)
        JSON.parse(body, symbolize_names:)
      end

      sig { returns(String) }
      def content_type
        headers.fetch("content-type").to_s
      end

      sig { returns(String) }
      def inspect
        "<##{self.class.name} url=#{url.inspect} status=#{status.inspect} status_text=#{status_text.inspect} content_type=#{content_type.inspect} body=#{body.bytesize}b>"
      end
    end

    extend T::Sig

    sig { void }
    def initialize
      @internet = T.let(Async::HTTP::Internet.new, Async::HTTP::Internet)
    end

    sig do
      params(
        url: String,
        method: Symbol,
        headers: T::Hash[String, String],
        body: T.nilable(String)
      ).returns(Response)
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
        ok: res.success?,
        redirected: res.redirection?
      )
    rescue => e
      puts "\e[32mFAILED ON #{url}\e[0m"
      raise
    end
  end
end
#
# Async do
#   fetch = Mayu::Fetch.new
#   res =
#     fetch.fetch(
#       "https://raw.githubusercontent.com/rack/rack/main/lib/rack/utils.rb"
#     )
#   p res
# end
