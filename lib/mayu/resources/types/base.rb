# frozen_string_literal: true
# typed: strict

require_relative "../resource"

module Mayu
  module Resources
    module Types
      class Base
        extend T::Sig

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource
        end

        sig { params(assets_dir: String).void }
        def generate_assets(assets_dir)
        end
      end
    end
  end
end
