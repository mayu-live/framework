# typed: strict

require "brotli"

module Mayu
  module Resources
    module Types
      class Stylesheet < Base
        class ClassnameProxy
          extend T::Sig

          sig { params(stylesheet: Stylesheet).void }
          def initialize(stylesheet)
            @stylesheet = stylesheet
          end

          sig { params(ident: Symbol).returns(String) }
          def method_missing(ident)
            @stylesheet.classes[ident.to_s].to_s
          end

          sig do
            params(
              args: T.any(String, Symbol),
              kwargs: T.nilable(T::Boolean)
            ).returns(String)
          end
          def [](*args, **kwargs)
            result = Set.new

            args.each do |classname|
              if klass = @stylesheet.classes[classname.to_s]
                result.add(klass)
              end
            end

            kwargs.each do |classname, value|
              next unless value

              if klass = @stylesheet.classes[classname.to_s]
                result.add(klass)
              end
            end

            result.join(" ")
          end
        end

        extend T::Sig

        sig { returns(T::Hash[String, String]) }
        attr_reader :classes

        sig { params(resource: Resource).void }
        def initialize(resource)
          super
          klasses = {}

          source =
            resource
              .read(encoding: "utf-8")
              .gsub(/\.\w+\b/) do |str|
                hash =
                  Base64.urlsafe_encode64(
                    Digest::SHA256.digest(resource.content_hash + str)
                  ).delete("=")

                name = str.delete_prefix(".")
                klasses[name] = "#{name}-#{hash}"
              end

          @source = T.let(source.freeze, String)
          @classes = T.let(klasses.freeze, T::Hash[String, String])
        end

        sig { returns(ClassnameProxy) }
        def classname_proxy
          ClassnameProxy.new(self)
        end

        sig { returns(T::Array[Asset]) }
        def assets
          [Asset.new(Base64.urlsafe_encode64(@resource.content_hash) + ".css")]
        end

        sig { params(asset_dir: String).returns(T::Array[Asset]) }
        def generate_assets(asset_dir)
          assets.each do |asset|
            asset.generate(asset_dir, @source, compress: true)
          end
        end

        MarshalFormat = T.type_alias { [T::Hash[String, String], String] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@classes, @source]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @classes, @source = args
        end
      end
    end
  end
end
