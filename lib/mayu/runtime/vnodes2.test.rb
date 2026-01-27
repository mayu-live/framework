#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require "stringio"
require_relative "../test"
require_relative "vnodes2/vdocument"
require_relative "vnodes2/patcher"

class Mayu::Runtime::VNodes2Test < Minitest::Test
  H = Mayu::Runtime::H

  EngineStub = Struct.new(:runtime_js)

  def test_write_html
    descriptor =
      H[
        :body,
        H[:header, H[:h1, "My webpage"]],
        H[:main, H[:p, "Welcome"]],
        H[:footer, H[:p, "Copyright"]]
      ]

    engine = EngineStub.new(nil)

    document =
      Mayu::Runtime::VNodes2::VDocument.new(
        descriptor,
        parent: engine,
        engine: engine
      )

    out = StringIO.new
    document.write_html(out)

    assert_equal(
      "<!DOCTYPE html>\n" \
        "<html><head><meta charset=\"utf-8\"></head>" \
        "<body><header><h1>My webpage</h1></header>" \
        "<main><p>Welcome</p></main>" \
        "<footer><p>Copyright</p></footer>" \
        "<mayu-ping ping=\"N/A\"></mayu-ping></body></html>\n",
      out.tap(&:rewind).read
    )
  end

  def test_update_patches_for_insert_and_remove
    initial =
      H[
        :body,
        H[:header, H[:h1, "My webpage"]],
        H[:main, H[:p, "Welcome"]],
        H[:footer, H[:p, "Copyright"]]
      ]

    updated =
      H[
        :body,
        H[:header, H[:h1, "My webpage"]],
        H[:main, H[:p, "Welcome"]],
        H[:section, H[:h2, "News"]]
      ]

    engine = EngineStub.new(nil)

    document =
      Mayu::Runtime::VNodes2::VDocument.new(
        initial,
        parent: engine,
        engine: engine
      )

    patcher = Mayu::Runtime::VNodes2::Patcher.new

    document.update(patcher, updated)

    create_patch =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::CreateTree)
      end
    remove_patch =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::RemoveNode)
      end

    refute_nil(create_patch)
    refute_nil(remove_patch)

    assert_match("<section><h2>News</h2></section>", create_patch.html)
    refute_nil(remove_patch.id)
  end

  def test_update_patches_for_attribute_and_text
    initial = H[:body, H[:p, "Hello", class: ["greeting"]]]
    updated = H[:body, H[:p, "World", class: ["farewell"]]]

    engine = EngineStub.new(nil)
    document =
      Mayu::Runtime::VNodes2::VDocument.new(
        initial,
        parent: engine,
        engine: engine
      )

    patcher = Mayu::Runtime::VNodes2::Patcher.new

    document.update(patcher, updated)

    set_attribute =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetAttribute) &&
          patch.name == :class
      end
    set_text =
      patcher.patches.find do |patch|
        patch.is_a?(Mayu::Runtime::Patches::SetTextContent)
      end

    refute_nil(set_attribute)
    assert_equal("farewell", set_attribute.value)

    refute_nil(set_text)
    assert_equal("World", set_text.content)
  end
end
