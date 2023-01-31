# typed: true
# frozen_string_literal: true

require_relative "interfaces"

module Mayu
  module VDOM
    module Reconciliation
      class RangeIterator
        def initialize(elements)
          @head = 0
          @tail = elements.length.pred
          @elements = elements
        end

        def done? = @head > @tail

        def head = @elements[@head]
        def tail = @elements[@tail]

        def tail_idx = @tail

        def next_head! = @head += 1
        def next_tail! = @tail -= 1

        def to_a = @elements[to_range] || []
        def to_range = @head..@tail

        def [](idx)
          @elements[idx]
        end

        def []=(idx, value)
          @elements[idx] = value
        end
      end

      module Patches
        extend T::Sig

        class Init < T::Struct
          const :descriptor, Interfaces::Descriptor
          def inspect = "#{self.class.name}(#{descriptor.type.to_s})"
        end

        class InsertBefore < T::Struct
          const :vnode, Interfaces::VNode
          const :ref, T.nilable(Interfaces::VNode)

          def inspect =
            "#{self.class.name}(#{vnode.id.inspect}, #{ref&.id.inspect})"
        end

        class InsertAfter < T::Struct
          const :vnode, Interfaces::VNode
          const :ref, T.nilable(Interfaces::VNode)

          def inspect =
            "#{self.class.name}(#{vnode.id.inspect}, #{ref&.id.inspect})"
        end

        class Patch < T::Struct
          const :vnode, Interfaces::VNode
          const :descriptor, Interfaces::Descriptor
          def inspect =
            "#{self.class.name}(#{vnode.id.inspect}, #{descriptor.type.to_s})"
        end

        class Remove < T::Struct
          const :vnode, Interfaces::VNode
          def inspect = "#{self.class.name}(#{vnode.id.inspect})"
        end

        Any =
          T.type_alias { T.any(Init, InsertBefore, InsertAfter, Patch, Remove) }
      end

      class Result < T::Struct
        const :vnodes, T::Array[Interfaces::VNode]
        const :patches, T::Array[Patches::Any]
      end

      extend T::Sig

      sig do
        params(
          old_children: T::Array[Interfaces::VNode],
          descriptors: T::Array[Interfaces::Descriptor],
          block:
            T
              .proc
              .params(arg0: Patches::Any)
              .returns(T.nilable(Interfaces::VNode))
        ).returns(Result)
      end
      def self.reconcile(old_children, descriptors, &block)
        # TODO: Make it possible to disable the following check in production:
        Children.check_duplicate_keys(descriptors)

        grouped = old_children.group_by { _1.descriptor }

        new_children =
          descriptors
            .map do |descriptor|
              if vnode = grouped[descriptor]&.shift
                yield Patches::Patch.new(vnode:, descriptor:)
              else
                yield Patches::Init.new(descriptor:)
              end
            end
            .compact

        patches = T.let([], T::Array[Patches::Any])

        delta_time_ms =
          Mayu::Utils.measure_time do
            patches.concat(diff(old_children, new_children))

            grouped.values.flatten.each do |removed|
              patches << Patches::Remove.new(vnode: removed)
            end
          end

        if delta_time_ms > 10
          Console.logger.warn(self, "Diffing took %.3fms" % delta_time_ms)
        end

        Result.new(vnodes: new_children, patches:)
      end

      def self.diff(old, new)
        old = old.dup
        new = new.dup

        old_ids = old.map(&:id).sort

        iold = RangeIterator.new(old)
        inew = RangeIterator.new(new)

        ops = []

        until iold.done? || inew.done?
          iold.next_head! and next unless iold.head
          iold.next_tail! and next unless iold.tail
          inew.next_head! and next unless inew.head
          inew.next_tail! and next unless inew.tail

          if iold.tail.eql?(inew.tail)
            iold.next_tail!
            inew.next_tail!
            next
          end

          if iold.head.eql?(inew.head)
            iold.next_head!
            inew.next_head!
            next
          end

          if iold.head.eql?(inew.tail)
            # Right move
            ops << Patches::InsertAfter.new(vnode: iold.head, ref: iold.tail)
            iold.next_head!
            inew.next_tail!
            next
          end

          if iold.tail.eql?(inew.head)
            # Left move
            ops << Patches::InsertBefore.new(vnode: iold.tail, ref: iold.head)
            inew.next_head!
            iold.next_tail!
            next
          end

          if old_index = old.find_index { _1.eql?(inew.head) }
            old[old_index] = nil
            ops << Patches::InsertBefore.new(vnode: inew.head, ref: iold.head)
            inew.next_head!
            next
          end

          ops << Patches::InsertBefore.new(vnode: inew.head, ref: iold.head)

          inew.next_head!
        end

        if iold.done?
          before = new[inew.tail_idx.succ]

          until inew.done?
            ops << Patches::InsertBefore.new(vnode: inew.head, ref: before)
            inew.next_head!
          end
        elsif inew.done?
          iold.to_a.compact.each do |vnode|
            # ops << Patches::Remove.new(vnode:)
          end
        end

        ops
      end
    end
  end
end
