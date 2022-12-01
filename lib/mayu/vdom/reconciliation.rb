# typed: strict
# frozen_string_literal: true

require_relative "indexes"

module Mayu
  module VDOM
    module Reconciliation
      extend T::Sig

      class Events < T::Enum
        enums do
          Patch = new
          Init = new
          Move = new
          Insert = new
          Remove = new
        end
      end

      Event =
        T.type_alias do
          T.any(
            [Events::Patch, vnode: VNode, descriptor: Descriptor],
            [Events::Init, descriptor: Descriptor],
            [Events::Move, vnode: VNode, before: T.nilable(VNode)],
            [Events::Insert, vnode: VNode, before: T.nilable(VNode)],
            [Events::Remove, vnode: VNode]
          )
        end

      sig do
        params(
          vnodes: T::Array[VNode],
          descriptors: T::Array[Descriptor],
          block: T.proc.params(arg0: Event).returns(T.nilable(VNode))
        ).returns(T::Array[VNode])
      end
      def self.reconcile(vnodes, descriptors, &block)
        Descriptor.check_duplicate_keys(descriptors)
        new_children = T.let([], T::Array[VNode])

        vnodes = vnodes.compact
        descriptors = descriptors.compact
        old_ids = vnodes.map(&:id)

        indexes = Indexes.new(vnodes.map(&:id))

        new_children =
          descriptors.map.with_index do |descriptor, i|
            vnode = vnodes.find { _1.same?(descriptor) }

            if vnode
              vnodes.delete(vnode)
              yield [Events::Patch, vnode:, descriptor:]
            else
              yield [Events::Init, descriptor:]
            end
          end

        # This is very inefficient.
        # I tried to get the algorithm from snabbdom/vue to work,
        # but it's not very easy to get right.
        # I always got some weird ordering issues and it's tricky to debug.
        # Fun stuff for later though.

        start_at = Time.now
        all_vnodes = vnodes + new_children

        new_children.each_with_index do |vnode, expected_index|
          new_indexes = Indexes.new(indexes.to_a - vnodes.map(&:id))
          current_index = indexes.index(vnode.id)

          before_id = indexes[expected_index]
          before = before_id && all_vnodes.find { _1.id == before_id } || nil

          if old_ids.include?(vnode.id)
            unless current_index == expected_index
              yield [Events::Move, vnode:, before:]
              indexes.insert_before(vnode.id, before_id)
            end
          else
            yield [Events::Insert, vnode:, before:]
            indexes.insert_before(vnode.id, before_id)
          end
        end

        vnodes.each { |vnode| yield [Events::Remove, vnode:] }

        delta_time_ms = (Time.now - start_at) * 1000

        if delta_time_ms > 10
          Console.logger.warn(self, "Updating took %.3fms" % delta_time_ms)
        end

        new_children
      end
    end
  end
end
