# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "runtime"
require_relative "session/token"

module Mayu
  class Session
    RequestInfo =
      Data.define(:path, :headers) do
        def self.from_request(request)
          new(path: request.path, headers: request.headers.to_h.freeze)
        end
      end

    TIMEOUT_SECONDS = 5

    attr_reader :id
    attr_reader :token

    def initialize(environment:, request_info:)
      @id = SecureRandom.alphanumeric(32)
      @token = Token.generate
      @environment = environment
      @request_info = request_info

      @engine =
        Runtime.init(
          resolve_route(@request_info.path),
          runtime_js: environment.runtime_js_for_session_id(@id)
        )

      @last_ping = Async::Clock.now
    end

    def self.resume_transferred(environment, encrypted_state)
      session = environment.marshaller.load(encrypted_state)
      session.instance_variable_set(:@environment, environment)
      session
    end

    def marshal_dump
      [@id, @token, @engine, @last_ping, @request_info]
    end

    def marshal_load(a)
      @id, @token, @engine, @last_ping, @request_info = a
    end

    def timed_out?
      diff = Async::Clock.now - @last_ping
      diff > TIMEOUT_SECONDS
    end

    def run(&block)
      @task =
        Async do |task|
          task.async do
            while Modules::System.current.wait_for_reload
              puts "\e[30;103mCode update detected, reloading.\e[0m"
              @engine.update(resolve_route(@request_info.path))
            end
          end

          @engine.run(&block)
        ensure
          @task = nil
        end
    end

    def wait
      @task&.wait
    end

    def stop
      @task&.stop
    end

    def render
      @engine.render
    end

    def handle_callback(id, payload)
      update_last_ping
      @engine.callback(id, payload)
    end

    def handle_navigate(path, push_state: true)
      update_last_ping
      @request_info = @request_info.with(path:)
      descriptor = resolve_route(path)
      @engine.navigate(path, descriptor, push_state:)
    end

    def handle_ping(timestamp)
      update_last_ping
      @engine.ping(timestamp)
    end

    def transfer!
      @engine.stop
      @engine.patch(
        Runtime::Patches::Transfer[
          Mayu::Server::EventStream::Blob[@environment.marshaller.dump(self)]
        ]
      )
    rescue => e
      Console.logger.error(self, e)
    end

    private

    def update_last_ping
      @last_ping = Async::Clock.now
    end

    def resolve_route(path)
      system = Modules::System.current

      match = @environment.router.match(path)

      layouts = [
        system.import("root.haml"),
        *match.route.layouts.map do
          p _1
          system.import(File.join("/pages", _1))
        end
      ]

      page =
        Mayu::Runtime::H[
          system.import(File.join("/pages", match.route.views.page)),
          params: match.params,
          query: match.query
        ]

      layouts
        .reverse
        .reduce(page) do |page, layout|
          Mayu::Runtime::H[
            layout,
            page,
            params: match.params,
            query: match.query,
            path:
          ]
        end
    end
  end
end
