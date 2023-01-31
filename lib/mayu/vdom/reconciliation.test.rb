# typed: true

require "minitest/autorun"
require "test_helper"
require_relative "../utils"
require_relative "reconciliation"
require_relative "descriptor"
require_relative "h"

class Mayu::VDOM::Reconciliation::Test < Minitest::Test
  class VNode < T::Struct
    extend T::Sig
    include Mayu::VDOM::Interfaces::VNode

    const :id, String, factory: -> { SecureRandom.alphanumeric(8) }
    prop :descriptor, Mayu::VDOM::Descriptor
  end

  def test_reconciliation
    descriptors = 200.times.map { |i| Mayu::VDOM::H[:li, i.to_s, key: i] }

    patches = []

    vnodes = T.let([], T::Array[VNode])

    p Mayu::Utils.measure_time { vnodes = update(vnodes, descriptors) }

    assert_equal(vnodes.map(&:descriptor), descriptors)

    descriptors = descriptors.shuffle

    p Mayu::Utils.measure_time { vnodes = update(vnodes, descriptors) }

    descriptors = descriptors.shuffle.slice(0..100).to_a

    p Mayu::Utils.measure_time { vnodes = update(vnodes, descriptors) }

    assert_equal(vnodes.map(&:descriptor).map(&:key), descriptors.map(&:key))
  end

  def update(vnodes, descriptors)
    Mayu::VDOM::Reconciliation
      .reconcile(vnodes, descriptors) do
        case _1
        in Mayu::VDOM::Reconciliation::Patches::Init => init
          VNode.new(descriptor: init.descriptor)
        in Mayu::VDOM::Reconciliation::Patches::Patch => patch
          vnode = patch.vnode
          vnode.descriptor = patch.descriptor
          vnode
        end
      end
      .vnodes
      .then { T.cast(_1, T::Array[VNode]) }
  end
end
