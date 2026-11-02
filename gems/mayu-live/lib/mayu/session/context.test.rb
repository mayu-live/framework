# frozen_string_literal: true

require "minitest/autorun"
require_relative "../runtime"
require_relative "../session"
require "mayu/test"
require "mayu/build"
require_relative "../environment"
require "tmpdir"
require "fileutils"

class Mayu::Session::ContextTest < Minitest::Test
  class Probe < Mayu::Component::Base
    attr_reader :initial_context

    def initialize
      @initial_context = session_context
    end

    def render
      H[:span, @initial_context.fetch(:label)]
    end
  end

  def test_context_survives_callbacks_navigation_reload_and_restoration
    Dir.mktmpdir("mayu-context") do |root|
      pages = File.join(root, "app", "pages")
      FileUtils.mkdir_p(File.join(pages, "next"))
      File.write(File.join(root, "app", "root.haml"), "%slot\n")
      source = <<~HAML
        :ruby
          def initialize
            @initial = session_context.fetch(:label)
          end
          def handle_click
            @seen = session_context.fetch(:label)
            rerender!
          end
        %button(onclick=handle_click)= "\#{@initial}:\#{@seen}"
      HAML
      ["+page.haml", "next/+page.haml", "+not-found.haml"].each do |name|
        File.write(File.join(pages, name), source)
      end
      provider = Mayu::Build::Configuration.new(root:).development_provider
      environment = Mayu::Environment.allocate
      environment.instance_variable_set(:@module_provider, provider)
      environment.instance_variable_set(:@metrics, Mayu::Test::FakeMetrics.new)
      server = Object.new
      def server.render_exceptions? = false
      environment.instance_variable_set(:@config, Struct.new(:server).new(server))
      session = Mayu::Session.new(environment:, request_info: Mayu::Session::RequestInfo.new(origin: "https://app.example", path: "/", headers: {}, http2: false), context: {label: "snapshot", secret: "hidden"})
      assert_includes session.render, "snapshot:"
      assert_equal "https://app.example", session.origin
      assert session.origin.frozen?
      refute_includes session.render, "hidden"
      engine = session.instance_variable_get(:@engine)
      Async do
        session.start
        consumer = Async::Task.current.async { loop { session.dequeue_batch.complete } }
        Async::Task.current.with_timeout(2) { engine.synchronize }
        listener = engine.root.instance_variable_get(:@listeners).values.find { it.callback&.method_name == :handle_click }
        completion = engine.callback(listener.id, {})
        Async::Task.current.with_timeout(1) { completion.dequeue }
        Async::Task.current.with_timeout(2) { engine.synchronize }
        assert_includes session.render, "snapshot:snapshot"
        ["/next", "/missing"].each do |path|
          session.send(:handle_event, Mayu::Session::Events::NavigateEvent["n", path, 1])
          Async::Task.current.with_timeout(2) { engine.synchronize }
          assert_includes session.render, "snapshot:"
          assert_equal({label: "snapshot", secret: "hidden"}, session.context)
          assert_equal "https://app.example", session.origin
        end
        session.send(:handle_reload_result, Mayu::HotReload::Update.success)
        Async::Task.current.with_timeout(2) { engine.synchronize }
        assert_includes session.render, "snapshot:"
        assert_equal "https://app.example", session.origin
      ensure
        consumer&.stop
        session.stop
      end.wait
      marshaller = Mayu::EncryptedMarshal.new("context-test-secret")
      transfer = Mayu::Session::TransferState.from_session(session)
      restored = Mayu::Session::TransferState.decrypt(marshaller, transfer.encrypt(marshaller)).resume(environment)
      assert_equal session.context, restored.context
      assert restored.context[:label].frozen?
      assert_equal session.origin, restored.origin
      assert restored.origin.frozen?
      assert_equal session.origin, restored.info.origin
      assert_includes restored.render, "snapshot:"
    ensure
      restored&.stop
      session&.stop
    end
  end

  def test_snapshot_is_detached_and_deeply_frozen
    original = {label: +"private", nested: [{"key" => "value"}]}
    snapshot = Mayu::Session::Context.snapshot(original)
    original[:label].replace("changed")
    assert_equal "private", snapshot[:label]
    assert snapshot.frozen?
    assert snapshot[:nested].first.keys.first.frozen?
    assert_raises(FrozenError) { snapshot[:nested].first["key"].replace("other") }
  end

  def test_invalid_context_is_rejected
    [{"key" => 1}, {key: Object.new}, {key: Float::NAN}].each do |value|
      assert_raises(ArgumentError) { Mayu::Session::Context.snapshot(value) }
    end
    cyclic = {}
    cyclic[:self] = cyclic
    assert_raises(ArgumentError) { Mayu::Session::Context.snapshot(cyclic) }
  end

  def test_context_is_installed_before_initialization_and_separate_from_providers
    engine = Mayu::Runtime::Engine.new(
      Mayu::Runtime::H.context(label: "provider") {
        Mayu::Runtime::H[Probe, session_context: {label: "prop"}]
      },
      metrics: Mayu::Test::FakeMetrics.new,
      session_context: {label: "snapshot", secret: "not in markup"}
    )
    assert_includes engine.render, "snapshot"
    refute_includes engine.render, "not in markup"
  end
end
