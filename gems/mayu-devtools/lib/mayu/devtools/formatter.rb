# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "mayu/runtime/commands"
require "mayu/runtime/descriptors"
require "mayu/component"

module Mayu
  module Devtools
    # Turns Ruby values into a tree the devtools panel can show:
    #
    #   {kind:, class:, value:, size:, entries: [{key:, value:}], truncated:}
    #
    # The tree is bounded in depth, entries and string length, so a large
    # value can't make an answer large. It never calls #inspect on objects it
    # doesn't know, since that can be slow or huge.
    class Formatter
      MAX_DEPTH = 4
      MAX_ENTRIES = 50
      MAX_STRING = 200
      # MessagePack can't pack integers wider than 64 bits.
      INTEGER_RANGE = (-(2**63))...(2**64)

      # `module_id` turns a source path into its Klenod module id, and
      # `original_line` a line of compiled code into the line of its template.
      def initialize(module_id: ->(path) { path }, original_line: ->(_path, line) { line })
        @module_id = module_id
        @original_line = original_line
      end

      def format(value)
        format_value(value, 0, Set.new.compare_by_identity)
      end

      # A Hash as entries, with each key written the way the source reads it,
      # such as `$title` for a prop.
      def entries(hash, prefix: "")
        seen = Set.new.compare_by_identity
        hash.first(MAX_ENTRIES).map do |key, value|
          {key: text("#{prefix}#{key}"), value: format_value(value, 1, seen)}
        end
      end

      # A callback as `Counter#increment app:/pages/Counter.haml:12`, with
      # where the template refers to it.
      def callback_label(callback)
        method = "#{component_name(callback.component)}##{callback.method_name}"
        text([method, location(*callback.source_location)].compact.join(" "))
      end

      private

      def format_value(value, depth, seen)
        case value
        when nil
          {kind: "nil"}
        when true, false
          {kind: "boolean", value:}
        when Integer
          INTEGER_RANGE.cover?(value) ? {kind: "number", value:} : {kind: "number", value: value.to_s}
        when Float
          value.finite? ? {kind: "number", value:} : {kind: "number", value: value.to_s}
        when String
          string(value)
        when Symbol
          {kind: "symbol", value: text(value.to_s)}
        when Proc, Method, UnboundMethod
          function(value)
        when Runtime::Descriptors::Callback
          {kind: "function", class: "Callback", value: callback_label(value)}
        when Module
          {kind: "class", value: text(value.name || value.to_s)}
        when Mayu::Component::Base
          component(value)
        else
          container(value, depth, seen)
        end
      end

      def container(value, depth, seen)
        class_name = text(value.class.name || value.class.to_s)
        return {kind: "cycle", class: class_name} if seen.include?(value)
        return {kind: "object", class: class_name, truncated: true} if depth >= MAX_DEPTH

        seen.add(value)
        begin
          case value
          when Hash
            collection(class_name, value.size, value.first(MAX_ENTRIES), depth, seen) { key_label(it) }
          when Array, Set
            items = value.first(MAX_ENTRIES).each_with_index.map { |item, index| [index, item] }
            collection(class_name, value.size, items, depth, seen, &:to_s)
          when Data, Struct
            members = value.to_h
            collection(class_name, members.size, members.first(MAX_ENTRIES), depth, seen, &:to_s)
          else
            ivars = value.instance_variables.first(MAX_ENTRIES).map { [it, value.instance_variable_get(it)] }
            collection(class_name, value.instance_variables.size, ivars, depth, seen, &:to_s)
              .merge(kind: "object")
          end
        ensure
          seen.delete(value)
        end
      end

      def collection(class_name, size, pairs, depth, seen)
        {
          kind: "collection",
          class: class_name,
          size:,
          entries: pairs.map do |key, item|
            {key: text(yield(key)), value: format_value(item, depth + 1, seen)}
          end,
          truncated: size > pairs.size
        }
      end

      def key_label(key)
        case key
        when Symbol then "#{key}:"
        when String then key.dump
        else key.to_s
        end
      end

      def string(value)
        value = text(value)
        if value.length > MAX_STRING
          {kind: "string", value: value[0, MAX_STRING], truncated: true}
        else
          {kind: "string", value:}
        end
      end

      def function(value)
        name = value.respond_to?(:name) ? value.name : nil
        label = [name, location(*value.source_location)].compact.join(" ")
        {kind: "function", class: value.class.name, value: text(label)}
      end

      def location(file = nil, line = nil)
        file && "#{@module_id.call(file)}:#{@original_line.call(file, line)}"
      end

      def component(value)
        path = value.class.module_path
        name = component_name(value)
        label = (path && !path.empty?) ? "#{name} (#{@module_id.call(path)})" : name
        {kind: "component", value: text(label)}
      end

      def component_name(component)
        component.class.name&.split("::")&.last || "(anonymous)"
      end

      def text(value) = Runtime::Commands.utf8(value)
    end
  end
end
