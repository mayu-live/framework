# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "message_cipher"

class Mayu::MessageCipher::Test < Minitest::Test
  def test_dump_and_load
    message_cipher = Mayu::MessageCipher.new(generate_key)

    dumped = message_cipher.dump("hello")
    loaded = message_cipher.load(dumped)

    assert_equal("hello", loaded)
  end

  def test_dump_and_load_object
    message_cipher = Mayu::MessageCipher.new(generate_key)

    object = { foo: "hello", bar: { baz: [123.456, :asd] } }

    dumped = message_cipher.dump(object)
    loaded = message_cipher.load(dumped)

    assert_equal(object, loaded)
  end

  def test_issued_in_the_future
    now = Time.now
    message_cipher = Mayu::MessageCipher.new(generate_key)

    dumped = message_cipher.dump("hello")

    Time.stub(:now, Time.at(Time.now - 1)) do
      assert_raises(Mayu::MessageCipher::IssuedInTheFutureError) do
        message_cipher.load(dumped)
      end
    end
  end

  def test_expiration
    now = Time.now
    message_cipher = Mayu::MessageCipher.new(generate_key)
    dumped = message_cipher.dump("hello")

    Time.stub(
      :now,
      Time.at(Time.now + Mayu::MessageCipher::DEFAULT_TTL_SECONDS)
    ) do
      assert_raises(Mayu::MessageCipher::ExpiredError) do
        message_cipher.load(dumped)
      end
    end
  end

  def test_invalid_key
    cipher1 = Mayu::MessageCipher.new(generate_key)
    cipher2 = Mayu::MessageCipher.new(generate_key)

    dumped = cipher1.dump("hello")

    assert_raises(Mayu::MessageCipher::DecryptError) { cipher2.load(dumped) }
  end

  private

  def generate_key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
end
