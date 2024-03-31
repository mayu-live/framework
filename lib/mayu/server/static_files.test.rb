#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"

require_relative "static_files"

class Mayu::Server::StaticFiles::Test < Minitest::Test
  def setup
    @root = File.join(__dir__, "..", "..", "..", "example", "app")
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
end
