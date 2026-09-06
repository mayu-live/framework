#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"

require_relative "../klenod"
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

  class Modal < Mayu::Component::Base
  end

  Route = Data.define(:page_module_id, :layout_module_ids)
  SpecialRoute = Data.define(:view_module_id, :layout_module_ids)
  SlotRoute = Data.define(:page_module_id, :layout_module_ids)
  SlotMatch = Data.define(:page, :params, :route, :layout_module_id)
  Match = Data.define(:page, :layouts, :params, :route, :slots)
  SpecialMatch = Data.define(:page, :layouts, :params, :route, :status)
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
        entry.start_with?("app:/") ? entry : "app:/#{entry}"
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

  def test_renders_parallel_route_matches_in_the_owning_layout_slot
    slot_route = SlotRoute.new("app:/pages/dashboard/@modal/+page.haml", [])
    slot_match =
      SlotMatch.new(
        Modal,
        { mode: "compose" },
        slot_route,
        "app:/pages/dashboard/+layout.haml"
      )
    route =
      Route.new(
        "app:/pages/dashboard/+page.haml",
        ["app:/pages/dashboard/+layout.haml"]
      )
    match = Match.new(Page, [Layout], {}, route, { modal: slot_match })

    resolved = router(match:).resolve("/dashboard?tab=overview")
    layout = resolved.descriptor.children.descriptors.fetch(0)
    modal = layout.children.slots.fetch(:modal).fetch(0)

    assert_equal(Modal, modal.type)
    assert_equal({ mode: "compose" }, modal.props[:params])
    assert_equal({ "tab" => "overview" }, modal.props[:query])
    assert_equal(
      %w[
        app:/root.haml
        app:/pages/dashboard/+layout.haml
        app:/pages/dashboard/+page.haml
        app:/pages/dashboard/@modal/+page.haml
      ],
      resolved.module_ids
    )
  end

  def test_resolves_a_not_found_page_with_its_status_and_assets
    not_found =
      SpecialMatch.new(
        Page,
        [Layout],
        {},
        SpecialRoute.new(
          "app:/pages/+not-found.haml",
          ["app:/pages/+layout.haml"]
        ),
        404
      )

    resolved = router(match: nil, not_found:).resolve("/missing")

    assert_equal(404, resolved.status)
    assert_equal("app:/pages/+not-found.haml", resolved.module_ids.last)
  end

  def test_resolves_an_error_page_with_error_props_and_status
    error_match =
      SpecialMatch.new(
        Page,
        [Layout],
        {},
        SpecialRoute.new("app:/pages/+error.haml", ["app:/pages/+layout.haml"]),
        500
      )
    exception = RuntimeError.new("boom")

    resolved =
      router(error: error_match).error("/posts/42?draft=true", error: exception)
    layout = resolved.descriptor.children.descriptors.fetch(0)
    page = layout.children.descriptors.fetch(0)

    assert_equal(500, resolved.status)
    assert_equal("/posts/42?draft=true", page.props[:path])
    assert_equal(500, page.props[:status])
    assert_same(exception, page.props[:error])
    assert_equal({ "draft" => "true" }, page.props[:query])
    assert_equal("app:/pages/+error.haml", resolved.module_ids.last)
  end

  def test_resolves_a_klenod_page_through_the_development_provider
    Dir.mktmpdir("mayu-klenod-router") do |root|
      FileUtils.mkdir_p(File.join(root, "app", "pages"))
      File.write(File.join(root, "app", "root.haml"), "%slot\n")
      File.write(File.join(root, "app", "pages", "+page.haml"), "%p Hello\n")

      provider = Mayu::Klenod::Configuration.new(root:).development_provider
      resolved = Mayu::Klenod::Router.new(provider).resolve("/")

      assert_equal(200, resolved.status)
      assert_equal(
        %w[app:/root.haml app:/pages/+page.haml],
        resolved.module_ids
      )
      assert_equal(Mayu::Component::Base, resolved.descriptor.type.superclass)
    end
  end

  private

  def router(
    match: Match.new(
      Page,
      [Layout],
      { id: "42" },
      Route.new("app:/pages/posts/+page.haml", ["app:/pages/+layout.haml"]),
      {}
    ),
    not_found: nil,
    error: nil
  )
    router = Module.new
    router.define_singleton_method(:match) { |_path| match }
    router.define_singleton_method(:not_found) { |_path| not_found }
    router.define_singleton_method(:error) { |_path| error }
    exports = Module.new
    exports.const_set(:Default, router)
    root_exports = Module.new
    root_exports.const_set(:Default, Root)

    Mayu::Klenod::Router.new(Provider.new(exports, root_exports))
  end
end
