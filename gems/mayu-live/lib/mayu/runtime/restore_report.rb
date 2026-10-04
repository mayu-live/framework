# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module Runtime
    # What happened to each component when a transferred engine was restored:
    # restored with its state, reinitialized because its code changed or its
    # state could not be restored, or unresolved because its class is gone.
    # Reinitialized components, and the closest ancestor of an unresolved one,
    # render again once the engine starts.
    class RestoreReport
      Entry = Data.define(:vnode, :component, :reason)

      attr_reader :restored, :reinitialized, :unresolved

      def initialize
        @restored = 0
        @reinitialized = []
        @unresolved = []
      end

      def restored!
        @restored += 1
      end

      def reinitialized!(vnode, component, reason)
        @reinitialized << Entry.new(vnode, component, reason)
      end

      def unresolved!(vnode, component, reason)
        @unresolved << Entry.new(vnode, component, reason)
      end

      def empty?
        @reinitialized.empty? && @unresolved.empty?
      end

      # The vnodes to render once the engine runs. An unresolved component can
      # not render, so its closest ancestor that can renders instead, which
      # replaces it.
      def vnodes_to_update
        unresolved = @unresolved.map(&:vnode)
        ancestors =
          unresolved.map do |vnode|
            ancestor = vnode.parent&.closest(vnode.class)
            ancestor = ancestor.parent&.closest(ancestor.class) while unresolved.include?(ancestor)
            ancestor || vnode.engine.root
          end

        [*@reinitialized.map(&:vnode), *ancestors].uniq
      end
    end
  end
end
