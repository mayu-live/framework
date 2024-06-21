# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "rbnacl"

module Mayu
  class Session
    module Token
      class InvalidTokenError < StandardError
      end

      TOKEN_LENGTH = 64

      def self.validate!(token)
        raise InvalidTokenError unless valid_format?(token)
      end

      def self.valid_format?(token)
        token.match?(/\A[[:alnum:]]{#{TOKEN_LENGTH}}\z/)
      end

      def self.generate
        SecureRandom.alphanumeric(TOKEN_LENGTH)
      end

      def self.equal?(a, b)
        RbNaCl::Util.verify64(a, b)
      end
    end
  end
end
