# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "mime/types"

MIME::Types["application/json"].first.add_extensions(%w[map])

require_relative "assets/asset"
require_relative "assets/encoded_content"
require_relative "assets/file_content"
require_relative "assets/generators"
require_relative "assets/storage"

module Mayu
  module Modules
    module Assets
    end
  end
end
