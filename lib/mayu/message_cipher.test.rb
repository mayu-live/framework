# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "message_cipher"

class TestMessageCipher < Minitest::Test
  def test_dump_and_load
    message_cipher = Mayu::MessageCipher.new(key: "test")

    dumped = message_cipher.dump("hello")
    loaded = message_cipher.load(dumped)
    assert(loaded == "hello")
  end
end
