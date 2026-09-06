#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require_relative "../component/base"
require_relative "../runtime/marshalling"
require_relative "component_resolver"

class Mayu::Klenod::ComponentResolverTest < Minitest::Test
  class SourceComponent < Mayu::Component::Base
    def self.module_path = "components/source.haml"
  end

  class ReloadedComponent < Mayu::Component::Base
  end

  Provider =
    Data.define(:exports_module) do
      def module_id_for(reference)
        raise KeyError unless reference == "components/source.haml"

        "app:/components/source.haml"
      end

      def exports(reference)
        raise KeyError unless reference == "app:/components/source.haml"

        exports_module
      end
    end

  def test_serializes_a_component_with_its_canonical_module_id
    resolver = Mayu::Klenod::ComponentResolver.new(provider)

    reference = resolver.dump_component_class(SourceComponent)

    assert_equal("app:/components/source.haml", reference.filename)
    assert_equal("SourceComponent", reference.class_name)
    assert_nil(reference.klass)
  end

  def test_resolves_the_default_export_after_a_component_rename
    resolver = Mayu::Klenod::ComponentResolver.new(provider)
    reference =
      Mayu::Runtime::Marshalling::ComponentRef.new(
        "app:/components/source.haml",
        "SourceComponent",
        nil
      )

    assert_equal(ReloadedComponent, resolver.resolve_component_ref(reference))
  end

  private

  def provider
    exports = Module.new
    exports.const_set(:Default, ReloadedComponent)
    Provider.new(exports)
  end
end
