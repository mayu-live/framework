# frozen_string_literal: true

require "async"
require "minitest/autorun"
require "minitest/focus"
require "stringio"

require_relative "../../../test"
require_relative "../../../modules/system"

require_relative "../../engine"
require_relative "../patcher"
require_relative "../vdocument"

module Mayu
  module Runtime
    module VNodes
      module TestHelpers
        H = Mayu::Runtime::H

        NullMetrics = Mayu::Test::FakeMetrics

        def run_engine(descriptor)
          engine =
            Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

          Async do
            engine.start
            yield engine
          ensure
            engine.stop
          end.wait
        end

        def run_engine_instance(engine)
          Async do
            engine.start
            yield
          ensure
            engine.stop
          end.wait
        end

        def wait_until(timeout: 0.2)
          deadline = Async::Clock.now + timeout

          until yield
            if Async::Clock.now >= deadline
              raise "timed out waiting for condition"
            end
            Async::Task.current.sleep(0)
          end
        end

        def render_html(document)
          out = StringIO.new
          document.write_html(out)
          out.tap(&:rewind).read
        end

        def unwrap_patches(patch)
          case patch
          when Mayu::Runtime::Patches::ViewTransition
            unwrap_patches(patch.patches)
          when Mayu::Runtime::Patches::Batch
            patch.patches
          when Array
            patch
          else
            [patch]
          end
        end

        def assert_no_patches(engine, timeout: 0.2)
          wait_until { engine.instance_variable_get(:@updater).queue.empty? }
          assert_raises(Async::TimeoutError) do
            Async::Task.current.with_timeout(timeout) { engine.dequeue_patches }
          end
        end

        def dequeue_until(engine, max_batches: 3, timeout: 0.5)
          max_batches.times do
            batch =
              Async::Task
                .current
                .with_timeout(timeout) { engine.dequeue_patches }
            patches = unwrap_patches(batch)
            return patches if yield(patches)
          end
          nil
        rescue Async::TimeoutError
          nil
        end

        def with_modules_system(component_class)
          mod = Module.new
          exports = Module.new
          exports.const_set(
            component_class.name.split("::").last,
            component_class
          )
          mod.const_set(:Exports, exports)
          mod.define_singleton_method(:assets) { [] }
          mod.define_singleton_method(:dependencies) { [] }

          system =
            Data
              .define(:mod) do
                def get_mod(_path)
                  mod
                end
              end
              .new(mod)

          key = Mayu::Modules::System::CURRENT_KEY
          previous = Thread.current.thread_variable_get(key)
          Thread.current.thread_variable_set(key, system)

          yield
        ensure
          Thread.current.thread_variable_set(key, previous)
        end

        def find_component(node, klass)
          if node.is_a?(Mayu::Runtime::VNodes::VComponent)
            instance = node.instance_variable_get(:@instance)
            return node if instance.is_a?(klass)
          end

          case node
          when Mayu::Runtime::VNodes::VDocument
            find_component(node.instance_variable_get(:@html), klass)
          when Mayu::Runtime::VNodes::VAny
            find_component(node.instance_variable_get(:@child), klass)
          when Mayu::Runtime::VNodes::VComponent
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes::VElement
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes::VCustomElement
            find_component(node.instance_variable_get(:@element), klass)
          when Mayu::Runtime::VNodes::VSlot, Mayu::Runtime::VNodes::VStateless
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes::VChildren
            node
              .instance_variable_get(:@children)
              .each do |child|
                found = find_component(child, klass)
                return found if found
              end
            nil
          else
            nil
          end
        end

        def find_element(node, type)
          if node.is_a?(Mayu::Runtime::VNodes::VElement)
            descriptor = node.instance_variable_get(:@descriptor)
            return node if descriptor&.type == type
          end

          case node
          when Mayu::Runtime::VNodes::VDocument
            find_element(node.instance_variable_get(:@html), type)
          when Mayu::Runtime::VNodes::VAny
            find_element(node.instance_variable_get(:@child), type)
          when Mayu::Runtime::VNodes::VComponent
            find_element(node.instance_variable_get(:@children), type)
          when Mayu::Runtime::VNodes::VElement
            find_element(node.instance_variable_get(:@children), type)
          when Mayu::Runtime::VNodes::VCustomElement
            find_element(node.instance_variable_get(:@element), type)
          when Mayu::Runtime::VNodes::VSlot, Mayu::Runtime::VNodes::VStateless
            find_element(node.instance_variable_get(:@children), type)
          when Mayu::Runtime::VNodes::VChildren
            node
              .instance_variable_get(:@children)
              .each do |child|
                found = find_element(child, type)
                return found if found
              end
            nil
          else
            nil
          end
        end
      end
    end
  end
end
