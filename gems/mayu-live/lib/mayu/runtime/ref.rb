# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "securerandom"

module Mayu
  module Runtime
    # Points at what a `ref` attribute was rendered on, like a React ref:
    #
    #   @input_ref = Ref.new
    #   %input(ref=@input_ref)
    #   @input_ref.current.focus
    #
    # `current` is an ElementHandle for an element and the component
    # instance for a component, or nil while nothing rendered with the ref
    # has started, such as during server rendering or after it was removed.
    #
    # A component's state and the rendered tree are marshalled separately,
    # so a session restore or a hot reload makes copies of a Ref. Copies
    # share the id, and the engine maps every copy it loads to one Ref, see
    # Engine#canonical_ref.
    class Ref
      attr_reader :id

      def initialize
        @id = SecureRandom.alphanumeric(16)
        @target = nil
      end

      def current
        @target&.ref_value
      end

      def attached? = !@target.nil?

      def ==(other)
        other.is_a?(Ref) && other.id == @id
      end
      alias_method :eql?, :==

      def hash = @id.hash

      def inspect = "#<#{self.class.name} #{@id}#{" attached" if attached?}>"

      def marshal_dump
        [@id]
      end

      def marshal_load(a)
        a => [id]
        @id = id
        @target = nil
      end

      # Called by the vnode that renders the ref, see Engine#attach_ref.
      def __attach(node)
        @target = node
      end

      # Only the node the ref points at can clear it: when a key or type
      # changes, the new node starts before the old one stops.
      def __detach(node)
        @target = nil if @target.equal?(node)
      end
    end

    # What `ref.current` returns for an element. Each method calls the DOM
    # method of the same name in the browser, after the DOM updates queued
    # before it, and returns nil. The browser only calls the methods listed
    # in client/src/element-calls.ts.
    class ElementHandle
      def initialize(vnode)
        @vnode = vnode
      end

      def inspect = "#<#{self.class.name} #{@vnode.dom_id}>"

      def focus(prevent_scroll: nil, focus_visible: nil)
        options = {preventScroll: prevent_scroll, focusVisible: focus_visible}.compact
        call("focus", options.empty? ? [] : [options])
      end

      def blur = call("blur")
      def click = call("click")
      def select = call("select")
      def reset = call("reset")
      def request_submit = call("request_submit")

      def scroll_into_view(behavior: nil, block: nil, inline: nil)
        options = {behavior:, block:, inline:}.compact
        call("scroll_into_view", options.empty? ? [] : [options])
      end

      def set_selection_range(start, finish, direction = nil)
        call("set_selection_range", [start, finish, direction].compact)
      end

      def show_modal = call("show_modal")
      def show = call("show")
      def close(return_value = nil) = call("close", [return_value].compact)
      def show_popover = call("show_popover")
      def hide_popover = call("hide_popover")
      def toggle_popover(force = nil) = call("toggle_popover", [force].compact)

      def marshal_dump
        raise TypeError, "Store the Ref in state, not ref.current"
      end

      private

      # Every call goes through here, so a call that waits for the browser's
      # answer can be added in one place later.
      def call(method, args = [])
        @vnode.engine.element_call(@vnode.dom_id, method, args)
        nil
      end
    end
  end
end
