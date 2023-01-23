# typed: true

require "minitest/autorun"
require "test_helper"
require_relative "descriptor"

class TestDescriptor < Minitest::Test
  class MyComponent < Mayu::Component::Base
    def render
    end
  end

  def test_element
    descriptor = Mayu::VDOM::Descriptor[:foo, key: "test-key"]
    assert_equal(descriptor.type, :foo)
    assert_equal(descriptor.props, { children: [] })
    assert_equal(descriptor.key, "test-key")
  end

  def test_component
    descriptor = Mayu::VDOM::Descriptor[MyComponent, key: "test-key"]
    assert_equal(descriptor.type, MyComponent)
    assert_equal(descriptor.props, { children: [] })
    assert_equal(descriptor.key, "test-key")
  end
end
