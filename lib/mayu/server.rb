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
      EnvInspector.new.inspect_env(env)

      case env["PATH_INFO"].to_s.split("/")
      in ['', '__mayu', 'live.js']
        send_file(
          File.join(JS_ROOT, 'live.js'),
          'application/javascript'
        )
      in ['', '__mayu', 'live', session_id]
        Session.connect(session_id)
      else
        Session.init
      end
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
  end
end
