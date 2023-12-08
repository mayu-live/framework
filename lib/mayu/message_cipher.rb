# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "time"
require "rbnacl"
require "securerandom"
require "brotli"

module Mayu
  class MessageCipher
    extend T::Sig

    DEFAULT_TTL_SECONDS = T.let(10, Integer)

    Message = T.type_alias { { iss: Float, exp: Float, payload: T.untyped } }

    class Error < StandardError
    end
    class ExpiredError < Error
    end
    class IssuedInTheFutureError < Error
    end
    class DecryptError < Error
    end

    sig { params(key: String, ttl: Integer).void }
    def initialize(key, ttl: DEFAULT_TTL_SECONDS)
      raise ArgumentError, "ttl must be positive" unless ttl.positive?
      @default_ttl_seconds = ttl
      @box =
        T.let(
          RbNaCl::SimpleBox.from_secret_key(RbNaCl::Hash.sha256(key)),
          RbNaCl::SimpleBox
        )
    end

    sig { params(payload: T.untyped, ttl: Integer).returns(String) }
    def dump(payload, ttl: @default_ttl_seconds)
      encode_message(Marshal.dump(payload), ttl:)
    end

    sig { params(data: String).returns(T.untyped) }
    def load(data)
      Marshal.load(decode_message(data))
    end

    private

    sig { params(payload: T.untyped, ttl: Integer).returns(String) }
    def encode_message(payload, ttl:)
      build_message(payload, ttl:)
        .then { Marshal.dump(_1) }
        .then { Brotli.deflate(_1) }
        .then { @box.encrypt(_1) }
    end

    sig { params(payload: String, ttl: Integer).returns(Message) }
    def build_message(payload, ttl:)
      validate_ttl!(ttl)

      now = Time.now.to_f

      { iss: now, exp: now + ttl, payload: }
    end

    sig { params(message: String).returns(String) }
    def decode_message(message)
      message
        .then { @box.decrypt(_1) }
        .then { Brotli.inflate(_1) }
        .then { Marshal.load(_1) }
        .then { validate_message(_1) }
    rescue RbNaCl::CryptoError => e
      raise DecryptError, e.message
    end

    sig do
      params(message: { iss: Float, exp: Float, payload: String }).returns(
        String
      )
    end
    def validate_message(message)
      message => { iss:, exp:, payload: }
      now = Time.now.to_f
      validate_iss!(now, iss)
      validate_exp!(now, exp)
      payload
    end

    sig { params(ttl: Integer).void }
    def validate_ttl!(ttl)
      raise ArgumentError, "ttl must be positive" if ttl < 0
    end

    sig { params(now: Float, iss: Float).void }
    def validate_iss!(now, iss)
      return if iss < now

      raise IssuedInTheFutureError,
            "The message was issued at #{Time.at(iss).iso8601}, which is in the future"
    end

    sig { params(now: Float, exp: Float).void }
    def validate_exp!(now, exp)
      return if exp > now

      raise ExpiredError,
            "The message expired at #{Time.at(exp).iso8601}, which is in the past"
    end
  end
end
