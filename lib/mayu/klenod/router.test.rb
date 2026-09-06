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

  Route = Data.define(:page_module_id, :layout_module_ids)
  Match = Data.define(:page, :layouts, :params, :route)
  Asset = Data.define(:url)
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

      def module_id_for(entry)
        "app:/#{entry}"
      end

      def assets_for_module(module_ids, type:)
        return [] unless type == :css

        module_ids.map do |module_id|
          Asset.new("/.mayu/assets/#{module_id.split(":/").last}.css")
        end
      end
    end

  def test_builds_a_root_and_layout_wrapped_page_descriptor
    resolved = router.resolve("/posts/42?draft=true")
    descriptor = resolved.descriptor

    assert_equal(200, resolved.status)
    assert_equal(
      %w[app:/root.haml app:/pages/+layout.haml app:/pages/posts/+page.haml],
      resolved.module_ids
    )
    assert_equal(
      %w[
        /.mayu/assets/root.haml.css
        /.mayu/assets/pages/+layout.haml.css
        /.mayu/assets/pages/posts/+page.haml.css
      ],
      resolved.stylesheets
    )
    assert_empty(resolved.scripts)

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
    assert_nil(router(match: nil).resolve("/missing"))
  end

  private

  def router(
    match: Match.new(
      Page,
      [Layout],
      { id: "42" },
      Route.new("app:/pages/posts/+page.haml", ["app:/pages/+layout.haml"])
    )
  )
    router = Module.new
    router.define_singleton_method(:match) { |_path| match }
    exports = Module.new
    exports.const_set(:Default, router)
    root_exports = Module.new
    root_exports.const_set(:Default, Root)

    Mayu::Klenod::Router.new(Provider.new(exports, root_exports))
  end
end
