#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require_relative "../component/base"
require_relative "../runtime/descriptors"
require_relative "router"

class Mayu::Klenod::RouterTest < Minitest::Test
  class Root < Mayu::Component::Base
  end

  class Layout < Mayu::Component::Base
  end

  class Page < Mayu::Component::Base
  end

  Match = Data.define(:page, :layouts, :params)
  Provider =
    Data.define(:router_exports, :root_exports) do
      def entry(name) = name

      def exports(entry)
        case entry
        when "virtual:router"
          router_exports
        when "root.haml"
          root_exports
        else
          raise KeyError, entry
        end
      end
    end

  def test_builds_a_root_and_layout_wrapped_page_descriptor
    descriptor = router.descriptor_for("/posts/42?draft=true")

    assert_equal(Root, descriptor.type)
    assert_equal("/posts/42?draft=true", descriptor.props[:path])

    layout = descriptor.children.descriptors.fetch(0)
    assert_equal(Layout, layout.type)
    assert_equal({ id: "42" }, layout.props[:params])
    assert_equal({ "draft" => "true" }, layout.props[:query])

    page = layout.children.descriptors.fetch(0)
    assert_equal(Page, page.type)
    assert_equal({ id: "42" }, page.props[:params])
    assert_equal({ "draft" => "true" }, page.props[:query])
  end

  def test_returns_nil_when_klenod_has_no_page_route
    assert_nil(router(match: nil).descriptor_for("/missing"))
  end

  private

  def router(match: Match.new(Page, [Layout], { id: "42" }))
    router = Module.new
    router.define_singleton_method(:match) { |_path| match }
    exports = Module.new
    exports.const_set(:Default, router)
    root_exports = Module.new
    root_exports.const_set(:Default, Root)

    Mayu::Klenod::Router.new(Provider.new(exports, root_exports))
  end
end
