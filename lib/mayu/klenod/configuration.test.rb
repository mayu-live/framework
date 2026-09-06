# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

require_relative "../klenod"

class Mayu::Klenod::ConfigurationTest < Minitest::Test
  def test_development_and_runtime_providers_share_the_same_entry_exports
    Dir.mktmpdir("mayu-klenod") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app", "entry.rb"), "VALUE = 42\n")

      configuration =
        Mayu::Klenod::Configuration.new(
          root:,
          entrypoints: ["entry"],
          output: ".mayu/app.bundle"
        )

      development = configuration.development_provider
      assert_equal(42, development.exports(development.entry("entry"))::VALUE)
      assert_equal("app:/entry.rb", development.module_id_for("entry").to_s)

      configuration.build
      runtime = configuration.runtime_provider

      assert_equal(42, runtime.exports("entry")::VALUE)
      assert_equal("app:/entry.rb", runtime.module_id_for("entry"))
      assert_equal("/.mayu/assets/", runtime.asset_base)
    end
  end

  def test_klenod_config_file_is_evaluated_against_mayu_defaults
    Dir.mktmpdir("mayu-klenod") do |root|
      File.write(File.join(root, "klenod.config.rb"), <<~RUBY)
          source_dir "frontend"
          pages_dir "routes"
          entrypoints "entry", "virtual:router"
          base "/assets/"
        RUBY

      configuration = Mayu::Klenod::Configuration.load(root:)

      assert_equal("frontend", configuration.source_dir)
      assert_equal("routes", configuration.pages_dir)
      assert_equal(
        %w[root.haml virtual:router entry virtual:router],
        configuration.entrypoints
      )
      assert_equal("/assets/", configuration.base)
    end
  end
end
