# frozen_string_literal: true
# typed: strict

module Mayu
  module Resources
    module Resolver
      class Base
        class ResolveError < StandardError
        end

        extend T::Sig
        extend T::Helpers
        abstract!

        sig { returns(T::Hash[String, String]) }
        attr_reader :resolved_paths

        sig { void }
        def initialize
          @resolved_paths = T.let({}, T::Hash[String, String])
        end

        sig do
          overridable.params(path: String, source_dir: String).returns(String)
        end
        def resolve(path, source_dir = "/")
          raise ResolveError, "Could not resolve #{path} from #{source_dir}"
        end
      end
    end
  end
end
