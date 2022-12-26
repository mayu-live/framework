# typed: strict

module Mayu
  module Metrics
    class Exporter
      class Server
        extend T::Sig

        sig do
          params(
            endpoint: Async::HTTP::Endpoint,
            registry: Prometheus::Client::Registry
          ).returns(Async::HTTP::Server)
        end
        def self.setup(endpoint:, registry:)
          Console.logger.info(
            self,
            "Starting metrics exporter on #{endpoint.to_url}"
          )

          Async::HTTP::Server.for(
            endpoint,
            protocol: Async::HTTP::Protocol::HTTP11
          ) do |request|
            if request.path == "/favicon.ico"
              next(
                Protocol::HTTP::Response[
                  404,
                  { "content-type": "text/plain" },
                  ["Not found"]
                ]
              )
            end

            body = Prometheus::Client::Formats::Text.marshal(registry)

            Protocol::HTTP::Response[
              200,
              { "content-type": "text/plain" },
              [body]
            ]
          end
        end
      end
    end
  end
end
