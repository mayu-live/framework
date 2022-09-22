# typed: strict

require "brotli"

module Mayu
  module Resources
    module Types
      class Stylesheet < Base
        extend T::Sig

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

                klasses[str] = "#{str}-#{hash}"
              end

          @source = T.let(source, String)
          @classes = T.let(klasses, T::Hash[String, String])
        end

        sig do
          params(
            args: T.any(String, Symbol),
            kwargs: T.nilable(T::Boolean)
          ).returns(String)
        end
        def classnames(*args, **kwargs)
          result = Set.new

          args.each do |classname|
            if klass = @classes[classname.to_s]
              result.add(klass)
            end
          end

          kwargs.each do |classname, value|
            next unless value

            if klass = @classes[classname.to_s]
              result.add(klass)
            end
          end

          result.join(" ")
        end

        sig { params(asset_dir: String).void }
        def generate_assets(asset_dir)
          path =
            File.join(
              asset_dir,
              Base64.urlsafe_encode64(@resource.content_hash) + ".css"
            )
          puts "\e[35mCreating #{path}\e[0m"
          File.write(path, @source)
          puts "\e[35mCompressing #{path}.br\e[0m"
          File.write(path + ".br", Brotli.deflate(@source))
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
