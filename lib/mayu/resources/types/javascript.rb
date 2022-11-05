# typed: strict
# frozen_string_literal: true

require "brotli"

module Mayu
  module Resources
    module Types
      class JavaScript < Base
        extend T::Sig

        sig { returns(String) }
        attr_reader :filename

        sig { params(resource: Resource).void }
        def initialize(resource)
          super
          @filename =
            T.let(
              Base64.urlsafe_encode64(@resource.content_hash).+(".js").freeze,
              String
            )
          @source = T.let(resource.read(encoding: "utf-8").freeze, String)
        end

        sig { returns(T::Array[Asset]) }
        def assets
          [
            Asset.new(
              filename,
              Generators::WriteFile.new(
                filename:,
                contents: @source,
                compress: true
              )
            )
          ]
        end

        MarshalFormat = T.type_alias { [String, String] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@filename, @source]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @filename, @source = args
        end
      end
    end
  end
end
