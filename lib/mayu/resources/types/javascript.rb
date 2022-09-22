# typed: strict

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

        sig { params(asset_dir: String).void }
        def generate_assets(asset_dir)
          path = File.join(asset_dir, @filename)
          puts "\e[35mCreating #{path}\e[0m"
          File.write(path, @source)
          puts "\e[35mCompressing #{path}.br\e[0m"
          File.write(path + ".br", Brotli.deflate(@source))
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
