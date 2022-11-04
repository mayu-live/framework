# typed: strict
# frozen_string_literal: true

require "crass"
require "base64"
require "digest/sha2"
require "set"

module Mayu
  module Resources
    module Transformers
      module CSS
        class Transformer
          class ClassMap
            extend T::Sig

            sig { params(path: String, content_hash: String).void }
            def initialize(path:, content_hash:)
              @layer_name = T.let("#{path}?#{content_hash}", String)

              @names =
                T.let(
                  Hash.new do |hash, key|
                    hash[key] = "#{path}.#{key}?#{content_hash}"
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
            @classes = T.let(ClassMap.new(path:, content_hash:), ClassMap)
          end

          sig { returns(String) }
          def layer_name = @classes.layer_name

          sig { returns(T::Hash[String, String]) }
          def classes = @classes.to_h

          sig do
            params(
              token: T.untyped,
              prev: T.untyped,
              selectors: T::Array[String]
            ).returns(T.untyped)
          end

          # stree-ignore
          def transform(token, prev = nil, selectors: [])
            case token
            in Array
              [nil, *token].each_cons(2)
                .map { |prev, curr| transform(curr, prev, selectors:) }
                .flatten
                .compact
            in { node: :property, name: "composes", value: }
              selectors.each { |selector| @classes.compose(selector, value) }
              nil
            in { node: :style_rule, selector:, children: }
              found_selectors = extract_class_names(selector)
              {
                **token,
                selector: transform(selector),
                children:
                  transform(
                    children,
                    selectors: found_selectors
                  ).flatten.compact
              }
            in node: :semicolon
              if prev in { node: :property, name: "composes" }
                nil
              else
                token
              end
            in { node: :selector, tokens: }
              { **token, tokens: transform_selector_tokens(tokens) }
            in { node: :simple_block, value: }
              { **token, value: transform(value) }
            in { node: :at_rule, name: "media", block: }
              { **token, block: transform_selector_tokens(block) }
            else
              token
            end
          end

          private

          sig { params(tokens: T::Array[T.untyped]).returns(T.untyped) }
          def transform_selector_tokens(tokens)
            [nil, *tokens].each_cons(2)
              .map do |prev, curr|
                if prev in { node: :delim, value: "." }
                  if curr in { node: :ident, value: }
                    raw = @classes[value]
                    next { **curr, raw:, value: @classes.escape_string(raw) }
                  end
                end

                if curr in { node: :function, name: "has", value: }
                  next { **curr, value: transform_selector_tokens(value) }
                end

                curr
              end
              .flatten
              .compact
          end

          sig { params(tokens: T.untyped).returns(T.untyped) }
          def extract_class_names(tokens)
            if tokens in { node: :selector, tokens: }
              return extract_class_names(tokens)
            end

            [nil, *tokens].each_cons(2)
              .map do |prev, curr|
                next extract_class_names(curr) if curr.is_a?(Array)

                # stree-ignore
                if prev in { node: :delim, value: "." }
                  if curr in { node: :ident, value: }
                    value
                  end
                end
              end
              .flatten
              .compact
              .uniq
          end
        end
      end
    end
  end
end
