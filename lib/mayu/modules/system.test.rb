# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require "tmpdir"
require "async"

require_relative "source_map"
require_relative "system"
require_relative "../watcher"

class Mayu::Modules::System::Test < Minitest::Test
  ImportRewriter = Mayu::Modules::ImportRewriter
  Rules = Mayu::Modules::Rules
  Loaders = Mayu::Modules::Loaders
  System = Mayu::Modules::System

  def test_rewrites_imports_to_hashes_and_keeps_dependency_graph
    Dir.mktmpdir("mayu-system-test") do |root|
      File.write(File.join(root, "a.rb"), <<~RUBY)
          Dep = import "./b"
        RUBY
      File.write(File.join(root, "b.rb"), "")

      system =
        System.new(
          root,
          rules: [Rules::Rule[/\.rb$/, Loaders::Ruby[]]],
          extensions: ["", ".rb"]
        )

      system.use do
        default_export = system.import("/a.rb")
        mod_a = system.get_mod("/a.rb")
        mod_b = system.get_mod("/b.rb")
        import_hash = ImportRewriter.hash_for("/b.rb")
        source = mod_a.instance_variable_get(:@source)

        assert_equal({ import_hash => "/b.rb" }, mod_a.imports)
        assert_equal(
          Set[Mayu::Modules::Dependency["/a.rb", import_hash, "/b.rb"]],
          mod_a.dependency_nodes
        )
        assert_equal(mod_b::Exports::Default, default_export::Dep)
        assert_includes(source, %(Dep = import("#{import_hash}")))
        refute_includes(source, %(Dep = import "./b"))
        assert_includes(mod_a.dependencies, "/b.rb")
        assert_includes(mod_b.dependants, "/a.rb")
      end
    end
  end

  def test_watch_update_does_not_reload_when_transformed_source_is_unchanged
    Dir.mktmpdir("mayu-system-test") do |root|
      source = <<~RUBY
        Dep = import "./d"
      RUBY

      File.write(File.join(root, "c.rb"), source)
      File.write(File.join(root, "d.rb"), "")

      system =
        System.new(
          root,
          rules: [Rules::Rule[/\.rb$/, Loaders::Ruby[]]],
          extensions: ["", ".rb"]
        )

      system.use do
        system.import("/c.rb")
        mod_c = system.get_mod("/c.rb")
        exports_before = mod_c::Exports.object_id

        File.write(File.join(root, "c.rb"), source)
        system.handle_watch_events([Mayu::Watcher::Events::Updated["/c.rb"]])

        assert_equal(exports_before, mod_c::Exports.object_id)
      end
    end
  end

  def test_watch_update_with_syntax_error_keeps_previous_exports
    Dir.mktmpdir("mayu-system-test") do |root|
      File.write(File.join(root, "c.rb"), %(Dep = import "./d"\n))
      File.write(File.join(root, "d.rb"), "")

      system =
        System.new(
          root,
          rules: [Rules::Rule[/\.rb$/, Loaders::Ruby[]]],
          extensions: ["", ".rb"]
        )

      system.use do
        system.import("/c.rb")
        mod_c = system.get_mod("/c.rb")
        exports_before = mod_c::Exports.object_id

        File.write(File.join(root, "c.rb"), "Dep = import(\n")
        system.handle_watch_events([Mayu::Watcher::Events::Updated["/c.rb"]])

        assert_equal(exports_before, mod_c::Exports.object_id)
      end
    end
  end

  def test_watch_update_with_syntax_error_signals_reload_failure
    Dir.mktmpdir("mayu-system-test") do |root|
      File.write(File.join(root, "c.rb"), %(Dep = import "./d"\n))
      File.write(File.join(root, "d.rb"), "")

      system =
        System.new(
          root,
          rules: [Rules::Rule[/\.rb$/, Loaders::Ruby[]]],
          extensions: ["", ".rb"]
        )

      system.use do
        system.import("/c.rb")
        File.write(File.join(root, "c.rb"), "Dep = import(\n")

        reload_result =
          Async do |task|
            waiter = task.async { system.wait_for_reload }
            system.handle_watch_events(
              [Mayu::Watcher::Events::Updated["/c.rb"]]
            )
            Async::Task.current.with_timeout(0.5) { waiter.wait }
          end.wait

        refute_nil(reload_result)
        refute(reload_result.success?)
        assert_equal([], reload_result.changed_paths)
        assert_equal(1, reload_result.errors.length)

        failure = reload_result.errors.first

        assert_equal("/c.rb", failure.file)
        assert_match(/ParseError/, failure.type)
        assert_equal(1, failure.line)
        assert_includes(failure.source, "Dep = import(")
        assert(failure.backtrace.any? { _1.start_with?("/c.rb:1") })
      end
    end
  end
end
