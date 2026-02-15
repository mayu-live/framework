#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require "minitest/mock"

require_relative "encrypted_marshal"

class Mayu::EncryptedMarshal::Test < Minitest::Test
  def test_dump_and_load
    message_cipher = Mayu::EncryptedMarshal.new(generate_key)

    dumped = message_cipher.dump("hello")
    loaded = message_cipher.load(dumped)

    assert_equal("hello", loaded)
  end

  def test_dump_and_load_object
    message_cipher = Mayu::EncryptedMarshal.new(generate_key)

    object = { foo: "hello", bar: { baz: [123.456, :asd] } }

    dumped = message_cipher.dump(object)
    loaded = message_cipher.load(dumped)

    assert_equal(object, loaded)
  end

  def test_issued_in_the_future
    message_cipher = Mayu::EncryptedMarshal.new(generate_key)

    dumped = message_cipher.dump("hello")

    Time.stub(:now, Time.at(Time.now - 1)) do
      assert_raises(Mayu::EncryptedMarshal::IssuedInTheFutureError) do
        message_cipher.load(dumped)
      end
    end
  end

  def test_expiration
    message_cipher = Mayu::EncryptedMarshal.new(generate_key)
    dumped = message_cipher.dump("hello")

    Time.stub(
      :now,
      Time.at(Time.now + Mayu::EncryptedMarshal::DEFAULT_TTL_SECONDS)
    ) do
      assert_raises(Mayu::EncryptedMarshal::ExpiredError) do
        message_cipher.load(dumped)
      end
    end
  end

  def test_custom_ttl_can_extend_validity
    message_cipher = Mayu::EncryptedMarshal.new(generate_key)
    base_time = Time.at(1_700_000_000)

    dumped =
      Time.stub(:now, base_time) do
        message_cipher.dump(
          "hello",
          ttl: Mayu::EncryptedMarshal::DEFAULT_TTL_SECONDS + 5
        )
      end

    loaded =
      Time.stub(
        :now,
        Time.at(base_time + Mayu::EncryptedMarshal::DEFAULT_TTL_SECONDS)
      ) { message_cipher.load(dumped) }

    assert_equal("hello", loaded)
  end

  def test_custom_ttl_can_shorten_validity
    message_cipher = Mayu::EncryptedMarshal.new(generate_key)
    base_time = Time.at(1_700_000_000)

    dumped = Time.stub(:now, base_time) { message_cipher.dump("hello", ttl: 1) }

    Time.stub(:now, Time.at(base_time + 1)) do
      assert_raises(Mayu::EncryptedMarshal::ExpiredError) do
        message_cipher.load(dumped)
      end
    end
  end

  def test_ttl_must_be_positive
    assert_raises(ArgumentError) do
      Mayu::EncryptedMarshal.new(generate_key, ttl: 0)
    end

    message_cipher = Mayu::EncryptedMarshal.new(generate_key)

    assert_raises(ArgumentError) { message_cipher.dump("hello", ttl: 0) }
  end

  def test_invalid_key
    cipher1 = Mayu::EncryptedMarshal.new(generate_key)
    cipher2 = Mayu::EncryptedMarshal.new(generate_key)

    dumped = cipher1.dump("hello")

    assert_raises(Mayu::EncryptedMarshal::DecryptError) { cipher2.load(dumped) }
  end

  private

  def generate_key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
end
