# frozen_string_literal: true
# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Types
      class Nil < Base
        extend T::Sig

        sig { returns(NilClass) }
        def marshal_dump
          nil
        end

        sig { params(args: NilClass).void }
        def marshal_load(args)
        end
      end
    end
  end
end
