# typed: strict

require "time"
require "digest/sha2"
require "openssl"
require "securerandom"
require "base64"
require "brotli"

module Mayu
  class MessageCipher
    extend T::Sig

    DEFAULT_TTL_SECONDS = T.let(10, Integer)
    DEFAULT_MESSAGE_PREFIX = T.let("mmc_", String)

    Message = T.type_alias { { iss: Float, exp: Float, payload: T.untyped } }

    class Error < StandardError
    end
    class ExpiredError < Error
    end
    class IssuedInTheFutureError < Error
    end
    class EncryptError < Error
    end
    class DecryptError < Error
    end
    class InvalidHMACError < Error
    end
    class InvalidPrefixError < Error
    end

    sig { params(key: String, prefix: String, ttl: Integer).void }
    def initialize(
      key:,
      prefix: DEFAULT_MESSAGE_PREFIX,
      ttl: DEFAULT_TTL_SECONDS
    )
      raise ArgumentError, "ttl must be positive" unless ttl.positive?
      @default_ttl_seconds = ttl
      @key = T.let(Digest::SHA256.digest(key), String)
      @prefix = prefix
    end

    sig do
      params(payload: T.untyped, auth_data: String, ttl: Integer).returns(
        String
      )
    end
    def dump(payload, auth_data: "", ttl: @default_ttl_seconds)
      raise ArgumentError, "ttl must be positive" unless ttl.positive?
      now = Time.now.to_f
      message = { iss: now, exp: now + ttl, payload: Marshal.dump(payload) }
      encode_message(message, auth_data:)
    end

    sig { params(data: String, auth_data: String).returns(T.untyped) }
    def load(data, auth_data: "")
      Marshal.load(decode_message(data, auth_data:))
    end

    private

    sig { params(message: Message, auth_data: String).returns(String) }
    def encode_message(message, auth_data: "")
      message
        .then { Marshal.dump(_1) }
        .then { prepend_hmac(_1) }
        .then { Brotli.deflate(_1) }
        .then { encrypt(_1, auth_data:) }
        .then { Base64.urlsafe_encode64(_1) }
        .prepend(@prefix)
    end

    sig { params(message: String, auth_data: String).returns(String) }
    def decode_message(message, auth_data: "")
      message
        .then { parse_prefix(_1) }
        .then { Base64.urlsafe_decode64(_1) }
        .then { decrypt(_1, auth_data:) }
        .then { Brotli.inflate(_1) }
        .then { validate_hmac(_1) }
        .then { Marshal.load(_1) }
        .tap { validate_times(_1) }
        .fetch(:payload)
    end

    sig { params(str: String).returns(String) }
    def parse_prefix(str)
      if str.start_with?(@prefix)
        str.delete_prefix(@prefix)
      else
        raise InvalidPrefixError,
              "The given message doesn't have the correct prefix"
      end
    end

    def prepend_hmac(input)
      hmac = Digest::SHA256.digest(input)
      input.prepend(hmac)
    end

    def validate_hmac(input)
      hmac, message = input.unpack("a32 a*")

      unless OpenSSL.fixed_length_secure_compare(
               hmac,
               Digest::SHA256.digest(message)
             )
        raise InvalidHMACError
      end

      message
    end

    sig { params(message: { iss: Float, exp: Float, payload: String }).void }
    def validate_times(message)
      message => { iss:, exp: }
      now = Time.now.to_f
      validate_iss(now, iss)
      validate_exp(now, exp)
    end

    sig { params(now: Float, iss: Float).void }
    def validate_iss(now, iss)
      return if iss < now

      raise IssuedInTheFutureError,
            "The message was issued at #{Time.at(iss).iso8601}, which is in the future"
    end

    sig { params(now: Float, exp: Float).void }
    def validate_exp(now, exp)
      return if exp > now

      raise ExpiredError,
            "The message expired at #{Time.at(exp).iso8601}, which is in the past"
    end

    sig { params(message: String, auth_data: String).returns(String) }
    def encrypt(message, auth_data: "")
      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.encrypt
      salt = SecureRandom.random_bytes(8)
      cipher.key = generate_key(salt)
      cipher.iv = iv = cipher.random_iv
      cipher.auth_data = auth_data
      cipher_text = cipher.update(message) + cipher.final
      auth_tag = cipher.auth_tag
      [auth_tag.bytesize, auth_tag, salt, iv, cipher_text].pack("C a* a* a* a*")
    rescue OpenSSL::Cipher::CipherError
      raise EncryptError
    end

    sig { params(data: String, auth_data: String).returns(String) }
    def decrypt(data, auth_data: "")
      data.unpack("C a*") => [Integer => auth_tag_len, String => data]

      data.unpack("a#{auth_tag_len} a8 a12 a*") => [
        auth_tag,
        salt,
        iv,
        cipher_text
      ]

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.iv = iv
      cipher.key = generate_key(salt)
      cipher.auth_data = auth_data
      cipher.auth_tag = auth_tag
      cipher.update(cipher_text) + cipher.final
    rescue OpenSSL::Cipher::CipherError
      raise DecryptError
    end

    sig { params(salt: String).returns(String) }
    def generate_key(salt)
      OpenSSL::KDF.scrypt(
        @key,
        salt:, # Salt.
        N: 2**14, # CPU/memory cost parameter. This must be a power of 2.
        r: 8, # Block size parameter.
        p: 1, # Parallelization parameter
        length: 32 # Length in octets of the derived key
      )
    end
  end
end
