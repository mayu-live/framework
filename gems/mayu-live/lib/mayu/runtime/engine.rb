# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "async/queue"
require "async/condition"
require "stringio"

require_relative "vnodes/vdocument"
require_relative "vnodes/updater"
require_relative "vnodes/command_collector"
require_relative "commands"
require_relative "marshalling"
require_relative "state_update_warning_event"

module Mayu
  module Runtime
    class Engine
      RENDER_TOKEN_KEY = :__mayu_render_token
      RENDER_GATE_INTERNAL_PATHS =
        [
          __FILE__,
          File.expand_path("vnodes/vcomponent.rb", __dir__),
          File.expand_path("../component/base.rb", __dir__),
          File.expand_path("../component/state.rb", __dir__)
        ].freeze

      attr_reader :runtime_js,
        :root,
        :output_queue,
        :metrics,
        :update_budget,
        :module_provider,
        :render_exceptions
      attr_writer :metrics
      attr_writer :update_budget
      attr_writer :module_provider
      attr_writer :render_exceptions

      # Seconds the updater waits after each pass, or nil to run as soon as
      # there is work. Set while the page is hidden.
      attr_accessor :update_interval
      alias_method :render_exceptions?, :render_exceptions

      def initialize(
        descriptor,
        metrics:, runtime_js: nil,
        update_budget: 30,
        module_provider: nil,
        render_exceptions: true,
        stylesheets: [],
        scripts: []
      )
        @runtime_js = runtime_js
        @metrics = metrics
        @update_budget = update_budget
        @module_provider = module_provider
        @render_exceptions = render_exceptions
        @vnode_id_sequence = 0
        @output_queue = Async::Queue.new
        @update_interval = nil
        @force_render = 0
        initialize_render_gate
        @updater = VNodes::Updater.new(@output_queue)
        @dirty_elements = Set.new
        @pending_custom_elements = Set.new
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
        @root.rebuild_listener_index!
      end

      def marshal_dump
        [
          @runtime_js,
          @root,
          @update_budget,
          @render_exceptions,
          @vnode_id_sequence
        ]
      end

      def marshal_load(a)
        case a
        in [runtime_js, root, update_budget, render_exceptions, vnode_id_sequence]
          @runtime_js = runtime_js
          @root = root
          @update_budget = update_budget
          @render_exceptions = render_exceptions
          @vnode_id_sequence = vnode_id_sequence
        in [runtime_js, root, update_budget, render_exceptions]
          @runtime_js = runtime_js
          @root = root
          @update_budget = update_budget
          @render_exceptions = render_exceptions
          @vnode_id_sequence = 0
        end
        @render_exceptions = true if @render_exceptions.nil?
        @output_queue = Async::Queue.new
        @update_interval = nil
        @force_render = 0
        initialize_render_gate
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
        if module_provider&.respond_to?(
          :component_resolver
        )
          resolver =
            module_provider.component_resolver
        end
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

      # Vnode IDs only need to be unique within an engine: one engine owns one
      # browser-side node map. Base 36 keeps long-lived sessions compact while
      # the prefix keeps IDs distinguishable from legacy random IDs.
      def next_vnode_id
        @vnode_id_sequence += 1
        @vnode_id_sequence.to_s(36).prepend("v").freeze
      end

      def synchronize
        @updater.synchronize
      end

      # A vnode handed the very descriptor object it already holds has nothing
      # new to show, unless a context provider above it changed its values:
      # consumers read context while rendering, so the provider runs its
      # subtree's update inside this block to make every component render.
      def force_render
        @force_render += 1
        yield
      ensure
        @force_render -= 1
      end

      def force_render?
        @force_render > 0
      end

      # Marks component rendering on the current fiber. Other fibers wait for
      # the outermost render to complete before they mutate component state.
      def with_render_gate
        previous_token = Thread.current[RENDER_TOKEN_KEY]
        outermost_render = @render_depth.zero?
        @render_depth += 1
        if outermost_render
          @render_fiber = Fiber.current
          @render_warnings.clear
        end
        Thread.current[RENDER_TOKEN_KEY] = @render_token
        yield
      ensure
        Thread.current[RENDER_TOKEN_KEY] = previous_token
        @render_depth -= 1
        if @render_depth.zero?
          @render_fiber = nil
          @render_finished.signal
        end
      end

      def wait_for_render_completion
        return unless @render_depth.positive?
        return if rendering_in_current_fiber?

        @render_finished.wait while @render_depth.positive?
      end

      def state_update_during_render?(component)
        return false unless rendering_in_current_fiber?
        return true unless @render_warnings.add?(component)

        location = caller_locations.find do |candidate|
          !RENDER_GATE_INTERNAL_PATHS.include?(candidate.absolute_path || candidate.path)
        end
        return true unless location

        event =
          StateUpdateWarningEvent.for(
            component,
            path: location.path,
            line: location.lineno,
            provider: module_provider
          )
        Console.logger.warn(component, event:)
        true
      end

      def callback(id, payload)
        @root.call_listener(id, payload)
      end

      def add_custom_element(custom_element)
        if @root
          @root.add_custom_element(custom_element)
        else
          @pending_custom_elements.add(custom_element)
        end
      end

      def flush_head(commands)
        @root.flush_head(commands)
      end

      def head_dirty?
        @root.head_dirty?
      end

      def register_dirty_element(element)
        @dirty_elements.add(element)
      end

      def register_dirty_listener_element(element)
        @root&.mark_listener_index_dirty(element)
      end

      def flush_dirty_elements(commands)
        return if @dirty_elements.empty?
        @dirty_elements.each do |element|
          next if element.removed?
          element.emit_replace_children(commands)
        end
        @dirty_elements.clear
      end

      def dequeue_batch
        @output_queue.dequeue
      end

      def render
        out = StringIO.new
        @root.write_html(out)
        out.tap(&:rewind).read
      end

      def dom_id_tree
        @root.dom_id_tree
      end

      def listener_commands
        @root.listener_commands
      end

      def styles
        @root.styles
      end

      def update(descriptor)
        @root.update(VNodes::NullCommandCollector.new, descriptor)
      end

      def same_descriptor?(left, right)
        return true if Descriptors.same?(left, right)
        return false unless left.is_a?(Descriptors::Element)
        return false unless right.is_a?(Descriptors::Element)
        return false unless left.key == right.key

        left_identity = component_identity(left.type)
        left_identity && left_identity == component_identity(right.type)
      end

      def migrate_component_state(state)
        with_component_resolver do
          dumped = Marshalling.dump_value(state)
          Marshalling.load_value(Marshal.load(Marshal.dump(dumped)))
        end
      end

      def rebind_component_instance(vnode_id, instance)
        @root.rebind_component_instance(vnode_id, instance)
      end

      def refresh(descriptor)
        if @updater&.task
          @root.assign_descriptor(descriptor)
          enqueue_update(@root)
        else
          update(descriptor)
        end
      end

      def navigate(descriptor, navigation_id:)
        if @updater&.task
          @root.assign_descriptor(descriptor)
          enqueue_update(@root)
          @updater.enqueue(VNodes::Updater::Navigation.new(navigation_id))
        else
          update(descriptor)
          enqueue_command(Commands::NavigationComplete[navigation_id])
        end
      end

      def enqueue_command(command)
        enqueue_batch(Batch[[command]])
      end

      def enqueue_batch(batch)
        unless batch.is_a?(Batch)
          raise ArgumentError, "Expected #{Batch}, got #{batch.class}"
        end

        @output_queue.enqueue(batch.validate!)
      end

      def ping(timestamp)
        enqueue_command(Commands::Pong[timestamp])
      end

      private

      def initialize_render_gate
        @render_depth = 0
        @render_token = Object.new
        @render_finished = Async::Condition.new
        @render_warnings = Set.new
        @render_fiber = nil
      end

      def rendering_in_current_fiber?
        @render_depth.positive? &&
          @render_fiber.equal?(Fiber.current) &&
          Thread.current[RENDER_TOKEN_KEY].equal?(@render_token)
      end

      def component_identity(type)
        return unless Marshalling.component_class?(type)

        if @module_provider&.respond_to?(
            :component_resolver
          )
          resolver =
            @module_provider.component_resolver
        end
        reference = resolver&.dump_component_class(type)
        return unless reference&.filename

        [reference.filename, reference.class_name]
      end

      def with_component_resolver(&)
        if @module_provider&.respond_to?(
          :component_resolver
        )
          resolver =
            @module_provider.component_resolver
        end
        Marshalling.with_component_resolver(resolver, &)
      end
    end
  end
end
