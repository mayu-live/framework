# frozen_string_literal: true
# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Types
      class SVG < Base
        extend T::Sig

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource

          source = resource.read(encoding: "utf-8")

          content_hash = Base64.urlsafe_encode64(Digest::SHA256.digest(source))

          @filename = T.let("#{content_hash}.svg", String)
          @source = T.let(source, String)
        end

        sig { returns(T::Array[Asset]) }
        def assets
          [
            Asset.new(
              @filename,
              Generators::WriteFile.new(contents: @source, compress: true)
            )
          ]
        end

        sig { returns(String) }
        def to_s = src

        sig { returns(String) }
        def src = "/__mayu/static/#{@filename}"

        MarshalFormat = T.type_alias { [String, String] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@source, @filename]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @source, @filename = args
        end
      end
    end
  end
end
