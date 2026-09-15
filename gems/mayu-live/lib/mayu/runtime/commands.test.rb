#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "msgpack"

require_relative "commands"

class Mayu::Runtime::CommandsTest < Minitest::Test
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
        [Mayu::Runtime::Commands::ViewTransition[inner]]
      ]

    assert_equal(
      [["ViewTransition", [["SetTextContent", "label", "Ready"]]]],
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
end
