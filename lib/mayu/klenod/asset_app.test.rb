# frozen_string_literal: true

require "minitest/autorun"

require "klenod/build/asset"

require_relative "asset_app"

class Mayu::Klenod::AssetAppTest < Minitest::Test
  Source =
    Data.define(:record) do
      def asset(output_path)
        raise KeyError, output_path unless output_path == record.output_path

        record
      end

      def asset_bytes(output_path, assets_dir: nil)
        raise KeyError, output_path unless output_path == record.output_path

        record.bytes
      end
    end

  Provider = Data.define(:source, :assets_dir, :asset_base)
  Request = Data.define(:path, :headers)

  def test_adapts_a_klenod_asset_response_to_protocol_http
    asset =
      Klenod::Build::Asset.new(
        "styles/site.css",
        "abc123",
        "/site.abc123.css",
        nil,
        "body {}",
        "text/css",
        { type: :css }
      )
    provider = Provider.new(Source.new(asset), nil, "/.mayu/assets/")

    response =
      Mayu::Klenod::AssetApp.new(provider).response_for(
        Request.new("/.mayu/assets/site.abc123.css", {})
      )

    assert_equal(200, response.status)
    assert_equal("text/css", response.headers["content-type"])
    assert_equal("body {}", response.body.read)
  end
end
