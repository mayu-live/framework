# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    class Import < BasicObject
      def initialize(mod)
        @mod = mod
      end

      def method_missing(...)
        __default_export.send(...)
      end

      def const_missing(const)
        __default_export.const_get(const)
      end

      private

      def __default_export
        @mod::Exports::Default
      end
    end
  end
end
