# frozen_string_literal: true
#
# These tests has been ported from ReactJS.
# https://github.com/facebook/react/blob/ec9400dc41715bb6ff0392d6320c33627fa7e2ba/packages/react-dom/src/__tests__/validate-test.js
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "bundler/setup"
require "minitest/autorun"
require "rexml"

require_relative "dom_nesting_validation"

class Mayu::Runtime::DOMNestingValidation::Test < Minitest::Test
  def test_valid_nestings
    assert_nil(get_warnings(:table, :tbody, :tr, :td, :b))
    assert_nil(get_warnings(:table, :tbody, :tr, :td, :b))
    assert_nil(get_warnings(:body, :datalist, :option))
    assert_nil(get_warnings(:div, :a, :object, :a))
    assert_nil(get_warnings(:div, :p, :button, :p))
    assert_nil(get_warnings(:p, :svg, :foreignObject, :p))
    assert_nil(get_warnings(:html, :body, :div))

    assert_nil(get_warnings(:div, :ul, :ul, :li))
    assert_nil(get_warnings(:div, :label, :div))
    assert_nil(get_warnings(:div, :ul, :li, :section, :li))
    assert_nil(get_warnings(:div, :ul, :li, :dd, :li))
  end

  def test_problematic_nestings
    assert_equal(<<~MSG.strip, get_warnings(:a, :a))
      In HTML, <a> can not be a descendant of <a>.
    MSG

    assert_equal(<<~MSG.strip, get_warnings(:form, :form))
      In HTML, <form> can not be a descendant of <form>.
    MSG

    assert_equal(<<~MSG.strip, get_warnings(:p, :p))
      In HTML, <p> can not be a descendant of <p>.
    MSG

    assert_equal(<<~MSG.strip, get_warnings(:table, :tr))
      In HTML, <tr> can not be a child of <table>. Add a <tbody>, <thead> or <tfoot> to your code to match the browser.
    MSG

    assert_equal(<<~MSG.strip, get_warnings(:div, :ul, :li, :div, :li))
      In HTML, <li> can not be a descendant of <li>.
    MSG

    assert_equal(<<~MSG.strip, get_warnings(:div, :html))
      In HTML, <html> can not be a child of <div>.
    MSG

    assert_equal(<<~MSG.strip, get_warnings(:body, :body))
      In HTML, <body> can not be a child of <body>.
    MSG

    assert_equal(<<~MSG.strip, get_warnings(:svg, :foreignObject, :body))
      In HTML, <body> can not be a child of <foreignObject>.
    MSG
  end

  private

  def get_warnings(*tags)
    tags => [*descendants, last]

    ancestor_info = Mayu::Runtime::DOMNestingValidation::AncestorInfo::EMPTY

    descendants.each do |descendant|
      ancestor_info = ancestor_info.update(descendant)
    end

    Mayu::Runtime::DOMNestingValidation.validate(last, ancestor_info)
  end
end
