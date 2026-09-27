#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require "mayu/component"
require_relative "formatter"

class Mayu::Devtools::FormatterTest < Minitest::Test
  Point = Data.define(:x, :y)

  class Plain
    def initialize
      @name = "plain"
    end
  end

  def formatted_value(value) = Mayu::Devtools::Formatter.new.format(value)

  def test_primitives
    assert_equal({kind: "nil"}, formatted_value(nil))
    assert_equal({kind: "boolean", value: true}, formatted_value(true))
    assert_equal({kind: "number", value: 1.5}, formatted_value(1.5))
    assert_equal({kind: "symbol", value: "open"}, formatted_value(:open))
    assert_equal({kind: "string", value: "hi"}, formatted_value("hi"))
  end

  def test_numbers_messagepack_cant_pack_become_strings
    assert_equal({kind: "number", value: (2**70).to_s}, formatted_value(2**70))
    assert_equal({kind: "number", value: "Infinity"}, formatted_value(Float::INFINITY))
  end

  def test_long_strings_are_cut
    formatted = formatted_value("a" * 500)

    assert_equal(Mayu::Devtools::Formatter::MAX_STRING, formatted[:value].length)
    assert(formatted[:truncated])
  end

  def test_hashes_arrays_and_data
    formatted = formatted_value({:title => "Hi", "count" => [1, Point.new(x: 1, y: 2)]})

    assert_equal("collection", formatted[:kind])
    assert_equal(["title:", "\"count\""], formatted[:entries].map { it[:key] })
    array = formatted[:entries].last[:value]
    assert_equal(2, array[:size])
    point = array[:entries].last[:value]
    assert_equal("Mayu::Devtools::FormatterTest::Point", point[:class])
    assert_equal(["x", "y"], point[:entries].map { it[:key] })
  end

  def test_large_collections_are_cut
    formatted = formatted_value((1..100).to_a)

    assert_equal(100, formatted[:size])
    assert_equal(Mayu::Devtools::Formatter::MAX_ENTRIES, formatted[:entries].size)
    assert(formatted[:truncated])
  end

  def test_cycles_are_marked
    array = [1]
    array << array

    assert_equal({kind: "cycle", class: "Array"}, formatted_value(array)[:entries].last[:value])
  end

  def test_depth_is_limited
    nested = [[[[[["deep"]]]]]]

    value = formatted_value(nested)
    4.times { value = value[:entries].first[:value] }

    assert_equal({kind: "object", class: "Array", truncated: true}, value)
  end

  def test_objects_show_their_instance_variables
    formatted = formatted_value(Plain.new)

    assert_equal("object", formatted[:kind])
    assert_equal([{key: "@name", value: {kind: "string", value: "plain"}}], formatted[:entries])
  end

  def test_procs_show_where_they_are_defined
    formatter = Mayu::Devtools::Formatter.new { "app:/#{File.basename(it)}" }
    formatted = formatter.format(-> {})

    assert_equal("function", formatted[:kind])
    assert_match(%r{\Aapp:/formatter\.test\.rb:\d+\z}, formatted[:value])
  end

  def test_entries_are_keyed_like_the_source
    entries = Mayu::Devtools::Formatter.new.entries({count: 1}, prefix: "@")

    assert_equal([{key: "@count", value: {kind: "number", value: 1}}], entries)
  end
end
