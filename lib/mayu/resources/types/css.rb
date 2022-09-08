# typed: strict

require "crass"
require_relative "base"

module Mayu
  module Resources
    module Types
      class CSS < Base
        sig { override.params(resource: Resource).returns(T.attached_class) }
        def self.load(resource)
          new(resource, File.read(resource.absolute_path))
        end

        class ClassnameProxy
          extend T::Sig

          sig { params(css: CSS).void }
          def initialize(css)
            @css = css
          end

          sig { params(ident: Symbol).returns(String) }
          def method_missing(ident)
            @css.get_ident(ident)
          end
        end

        sig { returns(String) }
        def inspect
          "#<CSSResourceule path=#{@path} idents=#{@class_names.keys.inspect}>"
        end

        sig { params(resource: Resource, src: String).void }
        def initialize(resource, src)
          super(resource)

          class_names = {}
          compositions = {}
          tree = Crass.parse(src, strict: true)
          tree = update_tree(tree, class_names, compositions)

          @class_names =
            T.let(
              class_names
                .map do |k, v|
                  [k, [v, compositions[k]].flatten.compact.uniq.join(" ")]
                end
                .to_h,
              T::Hash[String, String]
            )

          @src = T.let(Crass::Parser.stringify(tree).strip + "\n", String)
          @proxy = T.let(nil, T.nilable(ClassnameProxy))
          @hash = T.let(Digest::SHA256.digest(@src), String)

          @asset =
            T.let(
              Assets::Asset.from_content(
                content_type: "text/css",
                content: @src
              ),
              Assets::Asset
            )
        end

        sig { returns(Assets::Asset) }
        attr_reader :asset

        sig { returns(ClassnameProxy) }
        def proxy
          @proxy ||= ClassnameProxy.new(self)
        end

        sig { returns(String) }
        def to_s = @src

        sig { params(class_name: T.any(Symbol, String)).returns(String) }
        def get_ident(class_name)
          @class_names.fetch(class_name.to_s) do
            raise "Could not find #{class_name} in #{@class_names.keys}"
          end
        end

        private

        sig do
          params(
            node: T.untyped,
            class_names: T.untyped,
            compositions: T.untyped,
            selectors: T.untyped
          ).returns(T.untyped)
        end
        def update_tree(node, class_names, compositions, selectors = [])
          if node.is_a?(Array)
            nodes =
              node
                .map { update_tree(_1, class_names, compositions, selectors) }
                .compact

            nodes.select.with_index do |e, i|
              e[:node] != :semicolon && nodes[i + 1] != :semicolon
            end
          end

          if node.is_a?(Hash)
            if node[:node] == :style_rule
              selectors |=
                map_class_selectors(node[:selector]) do |token|
                  class_hash = hashify_ident(token[:value])
                  class_names[token[:value]] = class_hash
                  token[:raw] = class_hash
                  token[:value]
                end
            end

            if node[:node] == :property
              if node[:name] == "composes"
                selectors.each do |selector|
                  compositions[selector] ||= []
                  compositions[selector] += node[:value].split.map do
                    hashify_ident(_1)
                  end
                end

                return
              end
            end

            if node[:children]
              node[:children].delete_if { _1[:node] == :whitespace }

              return(
                node.merge(
                  children:
                    update_tree(
                      node[:children],
                      class_names,
                      compositions,
                      selectors
                    )
                )
              )
            end
          end

          node
        end

        sig { params(ident: String).returns(String) }
        def hashify_ident(ident)
          hash =
            Base64.urlsafe_encode64(Digest::SHA256.digest("#{hash} #{ident}"))
          "#{ident}-#{hash[0..5]}"
        end

        sig { params(node: T.untyped).returns(T.untyped) }
        def map_class_selectors(node)
          node[:tokens]
            .each_cons(2)
            .map do |prev, token|
              next unless token[:node] == :ident

              unless prev[:node] == :delim
                next if prev[:node] == :colon # :root {} etc

                unless prev[:value] == "."
                  raise "Only class selectors are supported, got `#{token[:value]}` at pos #{token[:pos]}"
                end
              end

              yield token
            end
            .compact
        end
      end
    end
  end
end
