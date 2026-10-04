# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console/event/generic"

require_relative "../backtrace"
require_relative "render_error_formatter"

module Mayu
  module Runtime
    # A component raised while rendering or handling an event. Logged through
    # Console, where Console::Terminal::Formatter::MayuRenderError draws it
    # for terminals and text log files and the JSON output writes #to_hash.
    class RenderErrorEvent < Console::Event::Generic
      TYPE = :"mayu.render_error"

      INTERNAL_PATH = "(internal)::"

      attr_reader :component

      # Call after the provider has rewritten the backtrace to source paths,
      # so app frames can be told apart from Mayu's and matched to sources.
      # `tree_path` is the vnode path from the document down to the failing
      # component, as `{name:, path:}` entries, the same list the overlay
      # shows. Component paths are shown as module ids, the way Klenod names
      # them, when the provider can resolve them.
      def self.for(error, component:, provider: nil, tree_path: [], root: Dir.pwd)
        backtrace, hidden_frames = Backtrace.split(error.backtrace)
        sources =
          if provider.respond_to?(:source_excerpts)
            provider.source_excerpts(error)
          else
            []
          end

        new(
          component: label_for(component, provider),
          error: error.class.name,
          message: error.message.to_s,
          backtrace:,
          hidden_frames:,
          sources:,
          tree_path: tree_path.map { |node| tree_node(node, provider) },
          root:
        )
      end

      def self.label_for(component, provider)
        klass = component&.class
        return nil unless klass

        path = klass.module_path if klass.respond_to?(:module_path)
        module_id(path, provider) || klass.to_s
      end

      # Components carry a path in the vnode tree, elements do not. The flag
      # keeps that distinction when an internal component's path is dropped.
      def self.tree_node(node, provider)
        node = node.to_h
        path = node[:path]
        entry = {name: node[:name].to_s}
        entry[:component] = true if path && !path.empty?
        id = module_id(path, provider)
        entry[:path] = id if id
        entry
      end

      def self.module_id(path, provider)
        return nil if path.nil? || path.empty? || path.start_with?(INTERNAL_PATH)
        return path unless provider.respond_to?(:module_id_for)

        provider.module_id_for(path).to_s
      rescue KeyError, ArgumentError
        path
      end

      def initialize(component:, error:, message:, backtrace:, hidden_frames:, sources:, tree_path:, root:)
        @component = component
        @error = error
        @message = message
        @backtrace = backtrace
        @hidden_frames = hidden_frames
        @sources = sources
        @tree_path = tree_path
        @root = root
      end

      def to_hash
        {
          type: TYPE,
          component: @component,
          error: @error,
          message: @message,
          backtrace: @backtrace,
          hidden_frames: @hidden_frames,
          sources: @sources,
          tree_path: @tree_path,
          root: @root
        }
      end
    end
  end
end
