# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

require_relative "../build"

class Mayu::Build::FaviconPluginTest < Minitest::Test
  def test_serves_favicon_ico_as_it_is
    with_app do |app_dir|
      bytes = ico_bytes(16, 32)
      File.binwrite(File.join(app_dir, "favicon.ico"), bytes)

      favicon = favicon_export(app_dir)

      assert_equal(bytes, favicon.fetch(:body))
      assert_equal(Encoding::BINARY, favicon.fetch(:body).encoding)
      assert_equal(::Klenod::Build::Hashing.short(bytes), favicon.fetch(:etag))
    end
  end

  def test_generates_an_ico_from_favicon_png
    with_app do |app_dir|
      write_png(File.join(app_dir, "favicon.png"), 64, 64)

      favicon = favicon_export(app_dir)

      assert_equal([[16, 16], [32, 32], [48, 48]], ico_sizes(favicon.fetch(:body)))
    end
  end

  def test_skips_sizes_larger_than_the_png
    with_app do |app_dir|
      write_png(File.join(app_dir, "favicon.png"), 32, 32)

      assert_equal([[16, 16], [32, 32]], ico_sizes(favicon_export(app_dir).fetch(:body)))
    end
  end

  def test_keeps_a_png_smaller_than_the_smallest_size
    with_app do |app_dir|
      write_png(File.join(app_dir, "favicon.png"), 8, 8)

      assert_equal([[8, 8]], ico_sizes(favicon_export(app_dir).fetch(:body)))
    end
  end

  def test_prefers_favicon_ico_over_favicon_png
    with_app do |app_dir|
      bytes = ico_bytes(16)
      File.binwrite(File.join(app_dir, "favicon.ico"), bytes)
      write_png(File.join(app_dir, "favicon.png"), 64, 64)

      assert_equal(bytes, favicon_export(app_dir).fetch(:body))
    end
  end

  def test_exports_nil_without_a_favicon
    with_app do |app_dir|
      assert_nil(favicon_export(app_dir))
    end
  end

  def test_rejects_a_png_that_is_not_square
    with_app do |app_dir|
      write_png(File.join(app_dir, "favicon.png"), 32, 16)

      error = assert_raises(Mayu::Build::FaviconPlugin::Error) { favicon_export(app_dir) }
      assert_match("favicon.png is 32x16, but a favicon must be square", error.message)
    end
  end

  def test_rejects_a_png_that_can_not_be_decoded
    with_app do |app_dir|
      File.write(File.join(app_dir, "favicon.png"), "not a png")

      assert_raises(Mayu::Build::FaviconPlugin::Error) { favicon_export(app_dir) }
    end
  end

  private

  def with_app
    Dir.mktmpdir("mayu-klenod") do |root|
      app_dir = File.join(root, "app")
      FileUtils.mkdir_p(app_dir)
      File.write(File.join(app_dir, "root.haml"), "%slot\n")
      yield app_dir
    end
  end

  def favicon_export(app_dir)
    provider = Mayu::Build::Configuration.new(root: File.dirname(app_dir)).development_provider
    provider.exports(provider.entry("virtual:mayu/favicon"))::Default
  end

  def write_png(path, width, height)
    image = Magick::Image.new(width, height) { |info| info.background_color = "red" }
    image.write(path)
  ensure
    image&.destroy!
  end

  def ico_bytes(*sizes)
    list = Magick::ImageList.new
    sizes.each { |size| list << Magick::Image.new(size, size) }
    list.to_blob { |info| info.format = "ICO" }
  ensure
    list&.each(&:destroy!)
  end

  def ico_sizes(bytes)
    Magick::Image.from_blob(bytes) { |info| info.format = "ICO" }.map do |image|
      [image.columns, image.rows]
    end
  end
end
