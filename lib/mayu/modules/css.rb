# typed: true

require "base64"
require "digest/sha2"
require "crass"
require_relative "../assets"

module Mayu
  module Modules
    module CSS
      def self.load(path)
        mod = CSSModule.new(path, File.read(path))
        Mayu::Assets::Manager.instance.add(path, "text/css", mod.to_s)
        mod
      rescue => e
        NoModule.new(path)
      end

      class IdentProxy < BasicObject
        def is_a?(klass)
          ::Object.instance_method(:is_a?).bind(self).call(klass)
        end
      end

      class Base
        extend T::Sig

        sig{ returns(String) }
        attr_reader :path

        sig{ params(path: String).void }
        def initialize(path)
          @path = path
        end

        def proxy
        end
      end

      class NoModule < Base
        class NoModuleProxy < IdentProxy
          def initialize(no_module)
            @no_module = no_module
          end

          def method_missing(*args)
            ::Kernel.raise "No CSS module loaded, please put your CSS in #{@no_module.path}"
          end
        end

        attr_reader :path

        def initialize(path)
          @path = path
        end

        def proxy
          @proxy ||= NoModuleProxy.new(self)
        end

        def to_s
          ""
        end
      end

      class CSSModule < Base
        class ClassnameProxy < IdentProxy
          def initialize(mod)
            @mod = mod
          end

          def method_missing(ident, *args)
            @mod.get_ident(ident)
          end
        end

        def inspect
          "#<CSSModule path=#{@path} idents=#{@class_names.keys.inspect}>"
        end

        def initialize(path, src)
          @path = path
          @hash = Digest::SHA256.digest(Digest::SHA256.digest(path) + Digest::SHA256.digest(src))

          class_names = {}
          compositions = {}
          tree = Crass.parse(src, strict: true)
          tree = update_tree(tree, class_names, compositions)

          @class_names =
            class_names
              .map do |k, v|
                [k, [v, compositions[k]].flatten.compact.uniq.join(" ")]
              end
              .to_h

          @src = Crass::Parser.stringify(tree).strip + "\n"
        end

        def proxy
          @proxy ||= ClassnameProxy.new(self)
        end

        def to_s
          @src
        end

        def get_ident(class_name)
          @class_names.fetch(class_name.to_s) do
            raise "Could not find #{class_name} in #{@class_names.keys}"
          end
        end

        private

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

        def hashify_ident(ident)
          hash = Base64.urlsafe_encode64(Digest::SHA256.digest(@hash + ident))
          "#{ident}-#{hash[0..5]}"
        end

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
