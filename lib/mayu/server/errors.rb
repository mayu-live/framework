# typed: strict
# frozen_string_literal: true

module Mayu
  module Server
    module Errors
      extend T::Sig

      class ServerError < StandardError
      end

      class FileNotFound < ServerError
      end
      class CookieNotSet < ServerError
      end
      class InvalidToken < ServerError
      end
      class InvalidMethod < ServerError
      end
      class SessionAlreadyResumed < ServerError
      end
      class SessionNotFound < ServerError
      end
      class ServerIsShuttingDown < ServerError
      end
      class InvalidSecFetchHeader < ServerError
      end

      sig do
        type_parameters(:R)
          .params(block: T.proc.returns(T.type_parameter(:R)))
          .returns(T.type_parameter(:R))
      end
      def self.handle_exceptions(&block)
        yield
      rescue Errno::ENOENT => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          404,
          { "content-type": "text/plain" },
          ["file not found"]
        ]
      rescue FileNotFound => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          404,
          { "content-type": "text/plain" },
          [e.message.to_s]
        ]
      rescue CookieNotSet => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          403,
          { "content-type": "text/plain" },
          ["missing session cookie"]
        ]
      rescue SessionNotFound => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          404,
          { "content-type": "text/plain" },
          ["session not found"]
        ]
      rescue Mayu::MessageCipher::DecryptError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          403,
          { "content-type": "text/plain" },
          ["decrypt error"]
        ]
      rescue Mayu::MessageCipher::ExpiredError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          403,
          { "content-type": "text/plain" },
          ["session expired"]
        ]
      rescue InvalidToken => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          403,
          { "content-type": "text/plain" },
          ["invalid token"]
        ]
      rescue SessionAlreadyResumed => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          409,
          { "content-type": "text/plain" },
          ["already resumed"]
        ]
      rescue Session::AlreadyRunningError => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          409,
          { "content-type": "text/plain" },
          ["already running"]
        ]

        # https://fly.io/docs/reference/fly-replay/#fly-replay
      rescue ServerIsShuttingDown => e
        Console.logger.error(self, "#{e.class.name}: #{e.message}")
        Protocol::HTTP::Response[
          503,
          { "fly-replay": "elsewhere=true" },
          ["Server is shutting down"]
        ]
      rescue InvalidMethod => e
        Console.logger.error(self, e)
        Protocol::HTTP::Response[
          405,
          { "content-type": "text/plain" },
          ["method not allowed"]
        ]
      rescue InvalidSecFetchHeader => e
        Console.logger.error(self, e)
        Protocol::HTTP::Response[
          415,
          { "content-type": "text/plain" },
          [e.message]
        ]
      rescue => e
        Console.logger.error(self, e)
        Protocol::HTTP::Response[500, {}, "error"]
      end
    end
  end
end
