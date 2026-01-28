# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "set"
require_relative "base"
require_relative "patcher"
require_relative "vcomponent"
require_relative "internal_components/html"
require_relative "internal_components/head"

module Mayu
  module Runtime
    module VNodes2
      class VDocument < Base
        H = Mayu::Runtime::H
        Html = InternalComponents::Html
        Head = InternalComponents::Head

        def initialize(descriptor, parent:, engine:)
          super
          @listeners = {}
          @styles = Set.new
          @head = Set.new
          @head_dirty = false
          @html = VComponent.new(init_html, parent: self, engine: @engine)
        end

        def dom_id_tree
          @html.dom_id_tree
        end

        attr_reader :head, :styles

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          @html.update(patcher, init_html)
        end

        def add_head(vnode)
          @head.add(vnode)
          @head_dirty = true
        end

        def remove_head(vnode)
          @head.delete(vnode)
          @head_dirty = true
        end

        def add_stylesheet(filename)
          @head_dirty = true if @styles.add?(filename)
        end

        def flush_head(patcher)
          return unless @head_dirty
          @html.update(patcher, init_html)
          @head_dirty = false
        end

        def start
          @html.start
        end

        def stop
          @html.stop
        end

        def write_html(out)
          @html.update(NullPatcher.new, init_html)
          out << "<!DOCTYPE html>\n"
          @html.write_html(out)
          out << "\n"
        end

        private

        def init_html
          H[Html, init_head, @descriptor]
        end

        def init_head
          H[
            Head,
            runtime_js: @engine.runtime_js,
            styles: @styles,
            descriptors: @head.map(&:children).flatten.compact
          ]
        end
      end
    end
  end
end
