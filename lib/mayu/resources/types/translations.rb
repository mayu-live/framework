# frozen_string_literal: true
# typed: strict

require "toml-rb"
require_relative "base"

module Mayu
  module Resources
    module Types
      class Translations < Base
        extend T::Sig

        FILENAME_RE = /\.intl\.(.+)\.toml\z/

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource

          @locale_identifier =
            T.let(File.basename(resource.path)[FILENAME_RE, 1].to_s, String)

          @translations =
            T.let(
              TomlRB.parse(
                resource.read(encoding: "utf-8"),
                symbolize_keys: true
              ),
              T::Hash[Symbol, T.untyped]
            )
        end

        sig { returns(T::Array[Asset]) }
        def assets
          []
        end

        sig { returns(T::Hash[Symbol, T.untyped]) }
        def to_h
          @translations
        end

        MarshalFormat = T.type_alias { [String, T::Hash[Symbol, T.untyped]] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@locale_identifier, @translations]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @locale_identifier, @translations = args
        end
      end
    end
  end
end
