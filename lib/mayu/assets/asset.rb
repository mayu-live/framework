# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Assets
    Asset = Data.define(:filename, :headers, :encoded_content)
  end
end
