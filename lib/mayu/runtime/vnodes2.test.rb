#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require_relative "../test"
require_relative "vnodes2/vdocument"

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
end
