# typed: strict
# frozen_string_literal: true

require "crass"
require "base64"
require "digest/sha2"
require "set"
require_relative "crass_patches"

module Mayu
  module Resources
    module Transformers
      module CSS
        class Transformer
          class ClassMap
            extend T::Sig

            sig do
              params(path: String, content_hash: String, separator: String).void
            end
            def initialize(path:, content_hash:, separator: ".")
              @layer_name = T.let("#{path}?#{content_hash}", String)

              @names =
                T.let(
                  Hash.new do |hash, key|
                    hash[key] = "#{path}#{separator}#{key}?#{content_hash}"
                  end,
                  T::Hash[String, String]
                )

              @composes =
                T.let(
                  Hash.new { |h, k| h[k] = Set.new },
                  T::Hash[String, T::Set[String]]
                )
            end

            sig { returns(String) }
            attr_reader :layer_name

            sig { params(source: String, target: String).void }
            def compose(source, target)
              T.must(@composes[source]).add(target)
            end

            sig { returns(T::Hash[String, String]) }
            def to_h
              @names
                .each_with_object({}) do |(key, value), obj|
                  obj[key] = [
                    value,
                    *T.must(@composes[key]).map { @names[_1] }
                  ].join(" ")
                end
                .freeze
            end

            sig { params(str: String).returns(String) }
            def escape_string(str)
              str.gsub(/[^\w-]/, '\\\\\0')
            end

            sig { params(name: String).returns(String) }
            def [](name)
              T.must(@names[name])
            end
          end

          extend T::Sig

          sig { params(path: String, content_hash: String).void }
          def initialize(path:, content_hash:)
            @classes =
              T.let(
                ClassMap.new(path:, content_hash:, separator: "."),
                ClassMap
              )
            @elements =
              T.let(
                ClassMap.new(path:, content_hash:, separator: "_"),
                ClassMap
              )
          end

          sig { returns(String) }
          def layer_name = @classes.layer_name

          sig { returns(T::Hash[String, String]) }
          def classes =
            @classes.to_h.merge(@elements.to_h.transform_keys { "__#{_1}" })
        end
      end
    end
  end
end
