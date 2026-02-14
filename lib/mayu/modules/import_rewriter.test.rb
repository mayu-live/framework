# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require "fileutils"
require "tmpdir"

require_relative "import_rewriter"
require_relative "resolver"

class Mayu::Modules::ImportRewriter::Test < Minitest::Test
  ImportRewriter = Mayu::Modules::ImportRewriter
  Resolver = Mayu::Modules::Resolver

  def test_rewrites_static_imports_and_returns_mapping
    Dir.mktmpdir("mayu-import-rewriter-test") do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      File.write(File.join(root, "app/dep.rb"), "Default = :dep\n")
      File.write(File.join(root, "app/dep2.rb"), "Default = :dep2\n")

      resolver = Resolver.new(root, extensions: ["", ".rb"])
      result =
        ImportRewriter.new(resolver:, source_path: "/app/page.rb").call(<<~RUBY)
          A = import "./dep"
          B = import("./dep2")
          C = import?("./maybe")
          D = something.import("./dep")
          E = import(path)
        RUBY

      dep_hash = ImportRewriter.hash_for("/app/dep.rb")
      dep2_hash = ImportRewriter.hash_for("/app/dep2.rb")

      assert_includes(result.source, %(A = import("#{dep_hash}")))
      assert_includes(result.source, %(B = import("#{dep2_hash}")))
      assert_includes(result.source, %(C = import?("./maybe")))
      assert_includes(result.source, %(D = something.import("./dep")))
      assert_includes(result.source, "E = import(path)")
      assert_equal(
        { dep_hash => "/app/dep.rb", dep2_hash => "/app/dep2.rb" },
        result.imports
      )
    end
  end
end
