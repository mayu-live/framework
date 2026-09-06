# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/queue"
require "set"
require "stringio"

require_relative "vnodes/vdocument"
require_relative "vnodes/updater"
require_relative "vnodes/patcher"
require_relative "patches"
require_relative "marshalling"

module Mayu
  module Runtime
    class Engine
      attr_reader :runtime_js,
                  :root,
                  :output_queue,
                  :metrics,
                  :update_budget,
                  :module_provider
      attr_writer :metrics
      attr_writer :update_budget
      attr_writer :module_provider

      def initialize(
        descriptor,
        runtime_js: nil,
        metrics:,
        update_budget: 30,
        module_provider: nil,
        stylesheets: [],
        scripts: []
      )
        @runtime_js = runtime_js
        @metrics = metrics
        @update_budget = update_budget
        @module_provider = module_provider
        @output_queue = Async::Queue.new
        @updater = VNodes::Updater.new(@output_queue)
        @dirty_elements = Set.new
        @pending_custom_elements = Set.new
        @pending_listeners = []
        @root =
          VNodes::VDocument.new(
            descriptor,
            parent: nil,
            engine: self,
            stylesheets:,
            scripts:
          )
        @pending_custom_elements.each do |custom_element|
          @root.add_custom_element(custom_element)
        end
        @pending_custom_elements.clear
        @pending_listeners.each { |listener| @root.add_listener(listener) }
        @pending_listeners.clear
      end

      def marshal_dump
        [@runtime_js, @root, @update_budget]
      end

      def marshal_load(a)
        @runtime_js, @root, @update_budget = a
        @output_queue = Async::Queue.new
        @updater = VNodes::Updater.new(@output_queue)
        @dirty_elements = Set.new
        @root.rehydrate(parent: nil, engine: self)
      end

      def dump
        with_component_resolver { Marshal.dump(self) }
      end

      def dump!
        stop
        dump
      end

      def self.restore(data, metrics: nil, module_provider: nil)
        resolver =
          module_provider.component_resolver if module_provider&.respond_to?(
          :component_resolver
        )
        engine =
          Marshalling.with_component_resolver(resolver) { Marshal.load(data) }
        engine.metrics = metrics if metrics
        engine.module_provider = module_provider
        engine
      end

      def self.restore!(data, metrics: nil, module_provider: nil)
        engine = restore(data, metrics:, module_provider:)
        engine.start
        engine
      end

      def task
        @updater.task
      end

      def update_budget=(value)
        @update_budget = value
      end

      def replace_route_assets(stylesheets:, scripts:)
        @root.replace_route_assets(stylesheets:, scripts:)
      end

      def start
        @updater.start(engine: self)
        @root.start
      end

      def stop
        @root.stop
        @updater.stop
        @task&.stop
      end

      def enqueue_update(vnode)
        @updater.enqueue(vnode)
      end

      def callback(id, payload)
        @root.call_listener(id, payload)
      end

      def add_listener(listener)
        @root ? @root.add_listener(listener) : @pending_listeners << listener
      end

      def remove_listener(listener)
        @root.remove_listener(listener)
      end

      def add_custom_element(custom_element)
        if @root
          @root.add_custom_element(custom_element)
        else
          @pending_custom_elements.add(custom_element)
        end
      end

      def flush_head(patcher)
        @root.flush_head(patcher)
      end

      def head_dirty?
        @root.head_dirty?
      end

      def register_dirty_element(element)
        @dirty_elements.add(element)
      end

      def flush_dirty_elements(patcher)
        return if @dirty_elements.empty?
        @dirty_elements.each do |element|
          element.emit_replace_children(patcher)
        end
        @dirty_elements.clear
      end

      def dequeue_patches
        @output_queue.dequeue
      end

      def dequeue_patch
        ensure_patch_buffer!
        @patch_buffer.shift
      end

      def render
        out = StringIO.new
        @root.write_html(out)
        out.tap(&:rewind).read
      end

      def dom_id_tree
        @root.dom_id_tree
      end

      def styles
        @root.styles
      end

      def update(descriptor)
        @root.update(VNodes::NullPatcher.new, descriptor)
      end

      def refresh(descriptor)
        if @updater&.task
          @root.assign_descriptor(descriptor)
          enqueue_update(@root)
        else
          update(descriptor)
        end
      end

      def navigate(path, descriptor, push_state: true)
        if @updater&.task
          @root.assign_descriptor(descriptor)
          enqueue_update(@root)
          @updater.enqueue(
            VNodes::Updater::Navigation.new(path, descriptor, push_state)
          )
        else
          update(descriptor)
          patch(Patches::HistoryPushState[path]) if push_state
        end
      end

      def patch(patches)
        Array(patches).flatten.each { |patch| @output_queue.enqueue(patch) }
      end

      def ping(timestamp)
        patch(Patches::Pong[timestamp])
      end

      private

      def with_component_resolver(&)
        resolver =
          @module_provider.component_resolver if @module_provider&.respond_to?(
          :component_resolver
        )
        Marshalling.with_component_resolver(resolver, &)
      end

      def ensure_patch_buffer!
        @patch_buffer ||= []
        if @patch_buffer.empty?
          patch = @output_queue.dequeue
          @patch_buffer = [patch]
        end
      end
    end
  end
end
