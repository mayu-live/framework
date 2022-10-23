# typed: strict
# frozen_string_literal: true

require_relative "../event_stream"

module Mayu
  class Session2
    extend T::Sig

    class AlreadyRunningError < StandardError
    end

    TIMEOUT_SECONDS = 10

    sig { returns(String) }
    attr_reader :id
    sig { returns(String) }
    attr_reader :token
    sig { returns(T.untyped) }
    attr_reader :state
    sig { returns(EventStream::Log) }
    attr_reader :log

    MarshalFormat = T.type_alias { [String, String, T.untyped] }

    sig { returns(MarshalFormat) }
    def marshal_dump
      [@id, @token, @state]
    end

    sig { params(a: MarshalFormat).void }
    def marshal_load(a)
      @id, @token, @state = a
      @last_activity = Time.now
      @run_task = nil
      @log = EventStream::Log.new
    end

    sig { params(token: String).void }
    def self.validate_token!(token)
      unless Base64.urlsafe_decode64(token).bytesize == 64
        raise ArgumentError, "invalid token"
      end
    end

    sig { void }
    def initialize
      @id = T.let(Nanoid.generate, String)
      @token = T.let(Base64.urlsafe_encode64(SecureRandom.bytes(64)), String)
      @state = T.let({ count: 0 }, T.untyped)
      @last_activity = T.let(Time.now, Time)
      @run_task = T.let(nil, T.nilable(Async::Task))
      @log = T.let(EventStream::Log.new, EventStream::Log)
    end

    sig { void }
    def activity!
      @last_activity = Time.now
    end

    sig { returns(String) }
    def color_id
      r, g, b = [Digest::SHA256.hexdigest(self.id)].pack("H*").unpack("CCC")
      "\e[38;2;#{r};#{g};#{b}m#{id}\e[0m"
    end

    sig { params(id: String, payload: T.untyped).void }
    def handle_callback(id, payload = {})
      @log.push(:handled_callback, id:, payload:)
    end

    sig { params(now: Time).returns(T::Boolean) }
    def timed_out?(now = Time.now)
      @run_task ? false : now - @last_activity > TIMEOUT_SECONDS
    end

    sig { void }
    def stop
      @run_task&.stop
    end

    sig do
      params(
        parent: Async::Task,
        block: T.proc.params(arg0: [Symbol, T.untyped]).void
      ).returns(Async::Task)
    end
    def run(parent: Async::Task.current, &block)
      raise AlreadyRunningError if @run_task

      @run_task =
        parent.async do |task|
          @last_activity = Time.now

          task.async do
            loop do
              @state[:count] += 1
              @state[:time] = Time.now.utc.iso8601(5)
              @state[:region] = ENV.fetch("FLY_REGION", "dev")
              @state[:alloc_id] = ENV.fetch("FLY_ALLOC_ID", "dev")

              yield [:state, @state]
              sleep 1.0
            end
          end
        ensure
          @run_task = nil
        end
    end

    sig { params(token: String).returns(T::Boolean) }
    def authorized?(token)
      if self.token.length == token.length
        OpenSSL.fixed_length_secure_compare(self.token, token)
      else
        false
      end
    end

    sig { params(ttl_seconds: Integer).returns(String) }
    def token_cookie(ttl_seconds: 60)
      expires = Time.now.utc + ttl_seconds

      cookie = [
        "mayu-token=#{self.token}",
        "path=/__mayu/session/#{self.id}/",
        "expires=#{expires.httpdate}",
        "secure",
        "HttpOnly",
        "SameSite=Strict"
      ].join("; ")
    end
  end
end
