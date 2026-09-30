#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

require_relative "../klenod"
require "mayu/build"

class Mayu::Klenod::ProviderTest < Minitest::Test
  MODELS = <<~RUBY
    module Kanban
      class Board
      end
    end

    Default = Kanban
  RUBY

  def test_classes_are_referenced_by_module_id_and_constant_path
    with_bundle(MODELS) do |provider|
      board = provider.exports("models")::Kanban::Board

      assert_match(/\A#<Module:0x\h+>::Mod_\h{24}::Exports::Kanban::Board\z/, board.name)
      assert_equal(["app:/models.rb", "Kanban::Board"], provider.class_reference(board))
      assert_same(board, provider.resolve_class("app:/models.rb", "Kanban::Board"))
    end
  end

  def test_references_resolve_in_another_process
    reference = with_bundle(MODELS) do |provider|
      provider.class_reference(provider.exports("models")::Kanban::Board)
    end

    with_bundle(MODELS) do |provider|
      board = provider.resolve_class(*reference)

      assert_same(provider.exports("models")::Kanban::Board, board)
    end
  end

  def test_other_classes_have_no_reference
    with_bundle(MODELS) do |provider|
      assert_nil(provider.class_reference(String))
      assert_nil(provider.class_reference(Class.new))
    end
  end

  def test_a_missing_class_is_reported_with_its_module
    with_bundle(MODELS) do |provider|
      error =
        assert_raises(Mayu::Klenod::UnresolvedClass) do
          provider.resolve_class("app:/models.rb", "Kanban::Column")
        end

      assert_includes(error.message, "Kanban::Column in app:/models.rb")
    end
  end

  def test_module_digests_change_only_with_the_source
    digest = ->(source) { with_bundle(source) { it.module_digest("app:/models.rb") } }

    assert_equal(digest.call(MODELS), digest.call(MODELS))
    refute_equal(digest.call(MODELS), digest.call(MODELS.sub("class Board", "class Board # changed")))
  end

  def test_the_development_provider_uses_the_same_references_and_digests
    Dir.mktmpdir("mayu-klenod") do |root|
      write_app(root, MODELS)
      provider = Mayu::Build::Configuration.new(root:, entrypoints: ["models"]).development_provider
      board = provider.exports(provider.entry("models"))::Kanban::Board

      assert_equal(["app:/models.rb", "Kanban::Board"], provider.class_reference(board))
      assert_equal(
        with_bundle(MODELS) { it.module_digest("app:/models.rb") },
        provider.module_digest("app:/models.rb")
      )
    end
  end

  private

  def with_bundle(source)
    Dir.mktmpdir("mayu-klenod") do |root|
      write_app(root, source)
      bundle_path = File.join(root, "app.mayu-bundle")
      Mayu::Build::Configuration.new(root:, entrypoints: ["models"]).build(output: bundle_path)

      yield Mayu::Klenod::RuntimeProvider.load(
        bundle_path,
        source_root: File.join(root, "app"),
        assets_dir: File.join(root, ".mayu", "assets")
      )
    end
  end

  def write_app(root, source)
    FileUtils.mkdir_p(File.join(root, "app"))
    File.write(File.join(root, "app", "models.rb"), source)
  end
end
