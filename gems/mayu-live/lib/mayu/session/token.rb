# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
        token.match?(/\A[[:alnum:]]{#{TOKEN_LENGTH}}\z/o)
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
