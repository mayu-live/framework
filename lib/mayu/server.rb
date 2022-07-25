# typed: strict

require 'rack'
require 'cgi'

require_relative "server/env_inspector"
require_relative "server/types"
require_relative "server/connection"
require_relative "server/session"

module Mayu
  module Server
    extend T::Sig

    JS_ROOT = T.let(File.join(File.dirname(__FILE__), 'client', 'dist'), String)
    NOT_FOUND_RESPONSE = T.let([404, {'content-type' => 'text/plain'}, ['not_found']], Types::TRackReturn)

    sig {params(env: Types::TRackHeaders).returns(Types::TRackReturn)}
    def self.call(env)
      case route_split(env)
      in :GET, ['__mayu', 'live.js']
        return send_file(
          File.join(JS_ROOT, 'live.js'),
          'application/javascript'
        )
      in :GET, ['__mayu', 'events', session_id]
        return Session.connect(session_id)
      in :POST, ['__mayu', 'handler', session_id, handler_id]
        body = JSON.parse(T.cast(env["rack.input"], Falcon::Adapters::Input).read)
        return Session.handle_event(session_id, handler_id)
      in :GET, path
        if env["HTTP_ACCEPT"].to_s.split(",").include?("text/html")
          return Session.init
        end
      end

        [404, {}, []]
    end

    sig {params(path: String, content_type: String).returns(Types::TRackReturn)}
    def self.send_file(path, content_type)
      [
        200,
        {'content-type' => content_type},
        [File.read(path)]
      ]
    rescue
      NOT_FOUND_RESPONSE
    end

    sig {params(env: Types::TRackHeaders).returns([Symbol, T::Array[String]])}
    def self.route_split(env)
      [
        env["REQUEST_METHOD"].to_s.to_sym,
        split_path(env["PATH_INFO"].to_s),
      ]
    end

    sig {params(path: String).returns(T::Array[String])}
    def self.split_path(path)
      path
        .sub(/^\//, '')
        .split("/")
    end
  end
end
