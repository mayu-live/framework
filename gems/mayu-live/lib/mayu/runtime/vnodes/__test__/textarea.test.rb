# frozen_string_literal: true

require_relative "test_helpers"

class Mayu::Runtime::VNodes::TextareaTest < Minitest::Test
  include Mayu::Runtime::VNodes::TestHelpers

  def build(textarea)
    Mayu::Runtime::Engine.new(H[:body, textarea], metrics: NullMetrics.new)
  end

  def test_empty_values_have_a_text_id_without_a_placeholder
    [H[:textarea], H[:textarea, ""], H[:textarea, value: ""], H[:textarea, initial_value: ""]].each do |descriptor|
      engine = build(descriptor)
      assert_includes(render_html(engine.root), "<textarea></textarea>")
      element = find_element(engine.root, :textarea)
      assert_equal(["#text"], element.dom_id_tree.first.children.map(&:name))
    end
  end

  def test_values_are_escaped_and_leading_newlines_and_zero_width_characters_survive
    engine = build(H[:textarea, value: "\n<&\u200b"])
    assert_includes(render_html(engine.root), "<textarea>\n\n&lt;&amp;\u200b</textarea>")
  end

  def test_both_html_writers_match
    engine = build(H[:textarea, initial_value: "\nhello"])
    element = find_element(engine.root, :textarea)
    out = StringIO.new
    element.write_html_with_id_tree(out, [])
    assert_equal("<textarea>\n\nhello</textarea>", out.string)
  end

  def test_conflicting_value_sources_are_rejected
    [H[:textarea, value: "", initial_value: ""], H[:textarea, "text", value: ""], H[:textarea, "text", initial_value: ""]].each do |descriptor|
      assert_raises(ArgumentError) { build(descriptor) }
    end
    assert_raises(ArgumentError) { build(H[:textarea, H[:b, "markup"]]) }
  end

  def test_controlled_updates_patch_the_value_and_keep_the_text_id
    engine = build(H[:textarea, value: ""])
    element = find_element(engine.root, :textarea)
    text_id = element.dom_id_tree.first.children.first.id
    collector = Mayu::Runtime::VNodes::CommandCollector.new
    element.update(collector, H[:textarea, value: "updated"])
    assert_includes(collector.commands, Mayu::Runtime::Commands::SetAttribute[element.dom_id, :value, "updated"])
    assert_includes(collector.commands, Mayu::Runtime::Commands::SetTextContent[text_id, "updated"])
    assert_equal(text_id, element.dom_id_tree.first.children.first.id)

    collector = Mayu::Runtime::VNodes::CommandCollector.new
    element.update(collector, H[:textarea, value: ""])
    assert_includes(collector.commands, Mayu::Runtime::Commands::SetTextContent[text_id, ""])
  end

  def test_nil_value_remains_controlled_and_clears_the_current_value
    engine = build(H[:textarea, value: "before"])
    element = find_element(engine.root, :textarea)
    collector = Mayu::Runtime::VNodes::CommandCollector.new
    element.update(collector, H[:textarea, value: nil])
    assert_includes(collector.commands, Mayu::Runtime::Commands::SetAttribute[element.dom_id, :value, ""])
    assert_includes(render_html(element), "<textarea></textarea>")
  end

  def test_transfer_preserves_textarea_defaults_and_ids
    engine = build(H[:textarea, initial_value: "saved"])
    restored = Marshal.load(Marshal.dump(engine))
    assert_equal(render_html(engine.root), render_html(restored.root))
    assert_equal(engine.dom_id_tree, restored.dom_id_tree)
  end
end
