# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "rbnacl"
require "brotli"

module Mayu
  class EncryptedMarshal
    class Error < StandardError
    end

    class IssuedInTheFutureError < Error
    end

    class ExpiredError < Error
    end

    class DecryptError < Error
    end

    AdditionalData =
      Data.define(:issued_at, :ttl) do
        def self.create(ttl:, now: Time.now) = new(now.to_f, ttl)

        def self.unpack(data)
          data.unpack("D S") => [issued_at, ttl]
          new(issued_at, ttl)
        end

        def pack = [issued_at, ttl].pack("D S")
        def expired?(now: Time.now) = now > expires_at
        def expires_at = Time.at(issued_at + ttl)
      end

    Message =
      Data.define(:nonce, :ad, :ciphertext) do
        def self.unpack(data)
          data.unpack("S a*") => [nonce_length, data]
          data.unpack("a#{nonce_length} S a*") => [nonce, ad_length, data]
          data.unpack("a#{ad_length} a*") => [ad, ciphertext]
          new(nonce, AdditionalData.unpack(ad), ciphertext)
        end

        def pack
          packed_ad = ad.pack
          [
            nonce.bytesize,
            nonce,
            packed_ad.bytesize,
            packed_ad,
            ciphertext
          ].pack("S a* S a* a*")
        end

        def expired?(now: Time.now) = ad.expired?(now:)
        def expires_at = ad.expires_at

        def verify_timestamps!(now: Time.now)
          if ad.expired?(now:)
            raise ExpiredError, "Message expired at #{ad.expires_at}"
          end

          if ad.issued_at > now.to_f
            raise IssuedInTheFutureError,
                  "Message was issued in the future, #{Time.at(ad.issued_at)}"
          end

          self
        end
      end

    extend T::Sig

    Cipher = RbNaCl::AEAD::ChaCha20Poly1305IETF

    DEFAULT_TTL_SECONDS = 10

    sig { returns(String) }
    def self.random_key = RbNaCl::Random.random_bytes(Cipher::KEYBYTES)

    sig { params(base_key: String, default_ttl: Integer).void }
    def initialize(base_key, default_ttl: DEFAULT_TTL_SECONDS)
      @cipher = Cipher.new(RbNaCl::Hash.sha256(base_key))
      @default_ttl = default_ttl
    end

    sig { params(object: T.untyped, ttl: Integer).returns(String) }
    def dump(object, ttl: @default_ttl) =
      object
        .then { Marshal.dump(_1) }
        .then { Brotli.deflate(_1) }
        .then { encrypt(_1, ttl:) }

    sig { params(encrypted: String).returns(T.untyped) }
    def load(encrypted) =
      encrypted
        .then { Message.unpack(_1) }
        .then { _1.verify_timestamps! }
        .then { decrypt(_1) }
        .then { Brotli.inflate(_1) }
        .then { Marshal.load(_1) }

    private

    def encrypt(message, ttl:)
      nonce = RbNaCl::Random.random_bytes(@cipher.nonce_bytes)
      ad = AdditionalData.create(ttl:)
      ciphertext = @cipher.encrypt(nonce, message, ad.pack)
      Message.new(nonce, ad, ciphertext).pack
    end

    def decrypt(message)
      @cipher.decrypt(message.nonce, message.ciphertext, message.ad.pack)
    rescue RbNaCl::CryptoError => e
      raise DecryptError, e.message
    end
  end
end
