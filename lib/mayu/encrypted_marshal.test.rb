require "minitest/autorun"
# require "test_helper"

require_relative "encrypted_marshal"

class Mayu::EncryptedMarshal::Test < Minitest::Test
  EncryptedMarshal = Mayu::EncryptedMarshal

  def test_dump_and_load
    encrypted_marshal = EncryptedMarshal.new(EncryptedMarshal.random_key)

    dumped = encrypted_marshal.dump("hello")
    loaded = encrypted_marshal.load(dumped)

    assert_equal("hello", loaded)
  end

  def test_dump_and_load_object
    encrypted_marshal = EncryptedMarshal.new(EncryptedMarshal.random_key)

    object = { foo: "hello", bar: { baz: [123.456, :asd] } }

    dumped = encrypted_marshal.dump(object)
    loaded = encrypted_marshal.load(dumped)

    assert_equal(object, loaded)
  end

  def test_issued_in_the_future
    encrypted_marshal = EncryptedMarshal.new(EncryptedMarshal.random_key)

    dumped = encrypted_marshal.dump("hello")

    Time.stub(:now, Time.at(Time.now - 1)) do
      assert_raises(EncryptedMarshal::IssuedInTheFutureError) do
        encrypted_marshal.load(dumped)
      end
    end
  end

  def test_expiration
    encrypted_marshal = EncryptedMarshal.new(EncryptedMarshal.random_key)
    dumped = encrypted_marshal.dump("hello")

    Time.stub(
      :now,
      Time.at(Time.now + EncryptedMarshal::DEFAULT_TTL_SECONDS)
    ) do
      assert_raises(EncryptedMarshal::ExpiredError) do
        encrypted_marshal.load(dumped)
      end
    end
  end

  def test_invalid_key
    em1 = EncryptedMarshal.new(EncryptedMarshal.random_key)
    em2 = EncryptedMarshal.new(EncryptedMarshal.random_key)

    dumped = em1.dump("hello")

    assert_raises(
      EncryptedMarshal::DecryptError,
      "Decryption failed. Ciphertext failed verification."
    ) { em2.load(dumped) }
  end
end
