#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "minitest/autorun"

require_relative "static_files"

class Mayu::Server::StaticFiles::Test < Minitest::Test
  def setup
    @root = File.join(__dir__, "..", "..", "..", "..", "..", "example", "app")
    @static_files = Mayu::Server::StaticFiles.new(@root)
  end

  def test_static_files
    robots = @static_files.get("robots.txt")
    assert_equal("text/plain", robots.content_type)
  end

  def text_nonexistant
    assert_nil @static_files.get("nonexistant")
  end

  def test_getting_out_of_root
    assert_nil @static_files.get("../Gemfile.lock")
  end
end

class Mayu::Server::StaticFiles::StaticFile::Test < Minitest::Test
  def test_static_file1
    asset =
      Mayu::Server::StaticFiles::StaticFile.build("/path/to/foo.txt", "content")

    assert_equal("text/plain", asset.content_type)
    assert_equal(:br, asset.encoded_content.encoding)
    assert_equal("content", Brotli.inflate(asset.encoded_content.content))
    assert_equal(
      "/path/to/foo.txt?yqy-cFH3rN6EyrcsWbBdog-NE1tHRkLWWO1sdhQVMNk",
      asset.filename
    )
    assert_equal(
      Digest::SHA256.digest(Brotli.deflate("content")),
      asset.content_hash
    )
  end

  def test_static_file2
    asset =
      Mayu::Server::StaticFiles::StaticFile.build("/path/to/foo.png", "content")

    assert_equal("image/png", asset.content_type)
    assert_nil(asset.encoded_content.encoding)
    assert_equal("content", asset.encoded_content.content)
    assert_equal(
      "/path/to/foo.png?7XACtDnprIRfIjV9giusFERzD722AW0-yUMil7nsn3M",
      asset.filename
    )
    assert_equal(Digest::SHA256.digest("content"), asset.content_hash)
  end

  def test_headers_leave_content_length_to_the_server
    asset =
      Mayu::Server::StaticFiles::StaticFile.build("/path/to/foo.js", "content")

    assert_equal(
      {
        "content-type": "text/javascript",
        "content-encoding": "br",
        vary: "accept-encoding"
      },
      asset.headers
    )
  end

  def test_a_client_that_reads_brotli_is_sent_brotli
    asset =
      Mayu::Server::StaticFiles::StaticFile.build("/path/to/foo.js", "content")

    representation = asset.representation(["gzip", "br"])

    assert_equal(:br, representation.encoding)
    assert_equal("content", Brotli.inflate(representation.content))
  end

  def test_a_client_that_does_not_read_brotli_is_sent_the_file_as_it_is
    asset =
      Mayu::Server::StaticFiles::StaticFile.build("/path/to/foo.js", "content")

    [nil, [], ["gzip", "deflate"], ["br;q=0"], "gzip, br;q=0.0"].each do |header|
      representation = asset.representation(header)

      assert_nil(representation.encoding, header.inspect)
      assert_equal("content", representation.content)
      assert_equal(
        {"content-type": "text/javascript", vary: "accept-encoding"},
        asset.headers(representation)
      )
    end
  end

  def test_a_file_that_is_not_compressed_does_not_vary
    asset =
      Mayu::Server::StaticFiles::StaticFile.build("/path/to/foo.png", "content")

    assert_equal("content", asset.representation(["br"]).content)
    assert_equal({"content-type": "image/png"}, asset.headers)
  end

  def test_source_maps_are_compressed
    asset =
      Mayu::Server::StaticFiles::StaticFile.build(
        "/path/to/main.js.map",
        "{\"version\":3}"
      )

    assert_equal("application/json", asset.content_type)
    assert_equal(:br, asset.encoded_content.encoding)
    assert_equal(
      "{\"version\":3}",
      Brotli.inflate(asset.encoded_content.content)
    )
  end

  def test_accept_encoding
    accepts = ->(header) { Mayu::Server::StaticFiles.accepts?(:br, header) }

    assert(accepts.call(["gzip", "deflate", "br", "zstd"]))
    assert(accepts.call("gzip, deflate, br"))
    assert(accepts.call(["gzip;q=1.0", "BR; q=0.5"]))
    assert(accepts.call(["*"]))
    assert(accepts.call(["gzip", "*;q=0.1"]))
    refute(accepts.call(nil))
    refute(accepts.call(["gzip"]))
    refute(accepts.call(["br;q=0"]))
    refute(accepts.call(["*", "br;q=0"]))
    refute(accepts.call(["*;q=0"]))
  end
end
