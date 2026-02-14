# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    Dependency =
      Data.define(:source_path, :import_hash, :resolved_path) do
        def to_s
          "#{source_path} --#{import_hash}--> #{resolved_path}"
        end
      end
  end
end
