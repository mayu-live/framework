# frozen_string_literal: true
# typed: strict

require "svg_optimizer"
require_relative "base"

module Mayu
  module Resources
    module Types
      class SVG < Base
        extend T::Sig

        SVG_OPTIMIZER_PLUGINS =
          T.let(
            SvgOptimizer::DEFAULT_PLUGINS -
              [
                # The following plugin sets fill="none" in some cases
                # which breaks the fontawesome icons... That's why
                # it's disabled...
                SvgOptimizer::Plugins::RemoveUselessStrokeAndFill
              ],
            T::Array[T.class_of(SvgOptimizer::Plugins::Base)]
          )

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource

          original = resource.read(encoding: "utf-8")
          optimized = SvgOptimizer.optimize(original)

          content_hash =
            Base64.urlsafe_encode64(Digest::SHA256.digest(optimized))

          @filename = T.let("#{content_hash}.svg", String)
          @source = T.let("#{optimized}\n", String)
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
