# frozen_string_literal: true

require "async"
require "minitest/autorun"
require "stringio"

require_relative "../../../test"
require_relative "../../../modules/system"

require_relative "../engine"
require_relative "../patcher"
require_relative "../vdocument"

module Mayu
  module Runtime
    module VNodes2
      module TestHelpers
        H = Mayu::Runtime::H

        def run_engine(descriptor)
          engine = Mayu::Runtime::VNodes2::Engine.new(descriptor)

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
          if node.is_a?(Mayu::Runtime::VNodes2::VComponent)
            instance = node.instance_variable_get(:@instance)
            return node if instance.is_a?(klass)
          end

          case node
          when Mayu::Runtime::VNodes2::VDocument
            find_component(node.instance_variable_get(:@html), klass)
          when Mayu::Runtime::VNodes2::VAny
            find_component(node.instance_variable_get(:@child), klass)
          when Mayu::Runtime::VNodes2::VComponent
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes2::VElement
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes2::VCustomElement
            find_component(node.instance_variable_get(:@element), klass)
          when Mayu::Runtime::VNodes2::VSlot, Mayu::Runtime::VNodes2::VStateless
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes2::VChildren
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
      end
    end
  end
end
