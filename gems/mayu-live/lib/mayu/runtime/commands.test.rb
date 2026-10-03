#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "msgpack"

require_relative "commands"

class Mayu::Runtime::CommandsTest < Minitest::Test
  def test_utf8_strips_colors_and_terminal_hyperlinks
    report =
      "\e[1;31m× Parse error\e[0m at " \
        "\e]8;;file:///app/broken.haml\e\\app:/broken.haml:2\e]8;;\e\\ " \
        "\e]8;;file:///app/x.rb\aapp:/x.rb:1\e]8;;\a"

    assert_equal(
      "× Parse error at app:/broken.haml:2 app:/x.rb:1",
      Mayu::Runtime::Commands.utf8(report)
    )
  end

  def test_element_call_serializes_its_node_method_and_arguments
    command =
      Mayu::Runtime::Commands::ElementCall["v1a", "focus", [{preventScroll: true}]]

    assert_equal(
      ["ElementCall", "v1a", "focus", [{"preventScroll" => true}]],
      MessagePack.unpack(MessagePack.pack(command))
    )
  end

  def test_batch_serializes_as_a_top_level_command_array
    batch =
      Mayu::Runtime::Batch[
        [
          Mayu::Runtime::Commands::Initialize[{id: "document"}],
          Mayu::Runtime::Commands::SetListener[
            "button",
            "click",
            "listener"
          ]
        ]
      ]

    assert_equal(
      [
        ["Initialize", {"id" => "document"}],
        ["SetListener", "button", "click", "listener"]
      ],
      MessagePack.unpack(MessagePack.pack(batch))
    )
  end

  def test_view_transition_contains_a_nested_batch_without_a_batch_opcode
    inner =
      Mayu::Runtime::Batch[
        [Mayu::Runtime::Commands::SetTextContent["label", "Ready"]]
      ]
    batch =
      Mayu::Runtime::Batch[
        [Mayu::Runtime::Commands::ViewTransition[inner, ["reorder"], nil]]
      ]

    assert_equal(
      [
        [
          "ViewTransition",
          [["SetTextContent", "label", "Ready"]],
          ["reorder"],
          nil
        ]
      ],
      MessagePack.unpack(MessagePack.pack(batch))
    )
  end

  def test_batch_rejects_non_commands
    batch = Mayu::Runtime::Batch[["not a command"]]

    assert_raises(ArgumentError) { batch.validate! }
  end

  def test_terminal_batch_detects_transfer_commands
    regular =
      Mayu::Runtime::Batch[[Mayu::Runtime::Commands::Pong[1]]]
    transfer =
      Mayu::Runtime::Batch[[Mayu::Runtime::Commands::Transfer["state"]]]

    refute(regular.terminal?)
    assert(transfer.terminal?)
  end

  def test_navigation_terminal_commands_serialize_the_navigation_id
    batch =
      Mayu::Runtime::Batch[
        [
          Mayu::Runtime::Commands::NavigationComplete["nav-1"],
          Mayu::Runtime::Commands::NavigationFailed["nav-2"]
        ]
      ]

    assert_equal(
      [["NavigationComplete", "nav-1"], ["NavigationFailed", "nav-2"]],
      MessagePack.unpack(MessagePack.pack(batch))
    )
  end
end
