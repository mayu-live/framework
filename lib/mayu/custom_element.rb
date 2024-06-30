# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  CustomElement =
    Data.define(:name, :filename) do
      def path
        "/.mayu/assets/#{filename}"
      end
    end
end
