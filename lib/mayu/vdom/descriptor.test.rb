# typed: true

require "minitest/autorun"
require_relative "descriptor"

class TestDescriptor < Minitest::Test
  class MyComponent < Mayu::VDOM::Component::Base
  end

  def test_initialize_descriptor
    descriptor = Mayu::VDOM::Descriptor.new(:foo, { key: "test-key" })
    assert_equal(descriptor.type, :foo)
    assert_equal(descriptor.props, { children: [] })
    assert_equal(descriptor.key, "test-key")
  end

  def test_initialize_component
    descriptor = Mayu::VDOM::Descriptor.new(MyComponent, { key: "test-key" })
    assert_equal(descriptor.type, MyComponent)
    assert_equal(descriptor.props, { children: [] })
    assert_equal(descriptor.key, "test-key")
  end
end
