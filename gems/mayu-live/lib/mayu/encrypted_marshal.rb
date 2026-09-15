# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "time"
require "rbnacl"
require "securerandom"
require "brotli"

module Mayu
  class EncryptedMarshal
    DEFAULT_TTL_SECONDS = 10

    Message = Data.define(:iss, :exp, :payload)

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

    class DumpError < Error
    end

    def initialize(key, ttl: DEFAULT_TTL_SECONDS)
      validate_ttl!(ttl)
      @default_ttl_seconds = ttl
      @box = RbNaCl::SimpleBox.from_secret_key(RbNaCl::Hash.sha256(key))
    end

    def dump(payload, ttl: @default_ttl_seconds)
      encode_message(Marshal.dump(payload), ttl:)
    rescue TypeError => e
      raise DumpError, "Could not dump payload: #{e.message}"
    end

    def load(data)
      Marshal.load(decode_message(data))
    end

    private

    def encode_message(payload, ttl:)
      build_message(payload, ttl:)
        .then { Marshal.dump(it) }
        .then { Brotli.deflate(it) }
        .then { @box.encrypt(it) }
    end

    def build_message(payload, ttl:)
      validate_ttl!(ttl)

      now = Time.now.to_f

      {iss: now, exp: now + ttl, payload:}
    end

    def decode_message(message)
      message
        .then { @box.decrypt(it) }
        .then { Brotli.inflate(it) }
        .then { Marshal.load(it) }
        .then { validate_message(it) }
    rescue RbNaCl::CryptoError => e
      raise DecryptError, e.message
    end

    def validate_message(message)
      message => {iss:, exp:, payload:}
      now = Time.now.to_f
      validate_iss!(now, iss)
      validate_exp!(now, exp)
      payload
    end

    def validate_ttl!(ttl)
      raise ArgumentError, "ttl must be positive" if ttl <= 0
    end

    def validate_iss!(now, iss)
      if iss > now
        raise IssuedInTheFutureError,
          "The message was issued at #{Time.at(iss).iso8601}, which is in the future"
      end
    end

    def validate_exp!(now, exp)
      if exp <= now
        raise ExpiredError,
          "The message expired at #{Time.at(exp).iso8601}, which is in the past or present"
      end
    end
  end
end
