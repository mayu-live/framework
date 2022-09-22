# frozen_string_literal: true
# typed: strict

module Mayu
  module Resources
    module Loader
      module Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig do
          abstract.params(resource: Resource).returns(Resources::Resource::Impl)
        end
        def load_impl(resource)
        end

        sig do
          overridable
            .params(resource: Resources::Resource, asset_dir: String)
            .void
        end
        def generate_assets(resource, asset_dir)
        end
      end
    end
  end
end
