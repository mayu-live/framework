# frozen_string_literal: true

require "minitest/autorun"
require "async"

require_relative "query_params"
require_relative "runtime/marshalling"

class Mayu::QueryParamsTest < Minitest::Test
  def test_symbol_lookups_keep_string_keys
    query = Mayu::QueryParams.parse("page=2&sort=name")

    assert_equal({"page" => "2", "sort" => "name"}, query)
    assert_equal(%w[page sort], query.keys)
    assert_equal("2", query[:page])
    assert_equal("2", query.fetch(:page))
    assert(query.key?(:page))
    assert_equal("2", query.dig(:page))
    assert_equal(%w[2 name], query.values_at(:page, "sort"))
    assert_equal(%w[2 name], query.fetch_values(:page, :sort))

    query[:offset] = "20"
    assert_equal("20", query["offset"])
    assert_includes(query.keys, "offset")
    refute_includes(query.keys, :offset)
  end

  def test_lookup_survives_session_value_marshalling
    query = Mayu::QueryParams.parse("page=2")
    restored =
      Mayu::Runtime::Marshalling.load_value(
        Mayu::Runtime::Marshalling.dump_value(query)
      )

    assert_instance_of(Mayu::QueryParams, restored)
    assert_equal("2", restored[:page])
    assert_equal(["page"], restored.keys)
  end
end
