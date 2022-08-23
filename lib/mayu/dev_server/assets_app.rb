# typed: false

module Mayu
  module DevServer
    class AssetsApp
      MOUNT_PATH = "/__mayu/assets"

      def call(env)
        asset =
          Mayu::Assets::Manager.find(File.basename(env[Rack::PATH_INFO].to_s))

        return 404, {}, ["File not found"] unless asset

        accept = env["HTTP_ACCEPT"].to_s.split(",")

        unless accept.include?("*/*") || accept.include?(asset.content_type)
          return [
            406,
            {},
            ["Not acceptable, try requesting #{asset.content_type} instead"]
          ]
        end

        headers = {
          "content-type" => asset.content_type,
          "cache-control" => "public, max-age=604800, immutable"
        }

        [200, headers, [asset.content]]
      end
    end
  end
end
