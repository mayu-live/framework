# frozen_string_literal: true
# typed: strict

require "digest"

module Mayu
  module Resources
    class Resource < Module
      class Wrapper < BasicObject
        extend ::T::Sig

        sig { params(impl: ::T.untyped).void }
        def initialize(impl)
          @impl = impl
        end

        sig do
          params(
            meth: ::Symbol,
            args: ::T.untyped,
            kwargs: ::T.untyped,
            block: ::T.untyped
          ).returns(::T.untyped)
        end
        def method_missing(meth, *args, **kwargs, &block)
          @impl.send(meth, *args, **kwargs, &block)
        end

        sig { params(impl: ::T.untyped).returns(::T.untyped) }
        def __replace_impl!(impl)
          @impl = impl
        end

        sig { returns(::String) }
        def inspect
          "#<Resource::Wrapper @impl=#{@impl.inspect}>"
        end
      end

      extend T::Sig

      Impl = T.type_alias { T.untyped }

      sig { returns(Registry) }
      attr_reader :registry
      sig { returns(String) }
      attr_reader :path
      sig { returns(String) }
      attr_reader :path_hash
      sig { returns(T.untyped) }
      attr_reader :wrapper

      sig { params(registry: Registry, path: String).void }
      def initialize(registry:, path:)
        @registry = registry
        @path = path
        @path_hash = T.let(Digest::SHA256.hexdigest(path), String)
        @type = T.let(nil, T.untyped)
        @wrapper = T.let(Wrapper.new(nil), T.untyped)
        @content_hash = T.let(nil, T.nilable(String))
      end

      sig { params(encoding: String).returns(String) }
      def read(encoding: "binary")
        File.read(absolute_path)
      end

      sig { returns(T::Boolean) }
      def exists?
        File.exist?(absolute_path)
      end

      sig { returns(String) }
      def content_hash
        @content_hash ||= calculate_content_hash
      end

      sig { returns(String) }
      def calculate_content_hash
        Digest::SHA256.file(absolute_path).digest
      end

      sig { returns(T::Array[Asset]) }
      def assets
        self.type&.assets || []
      end

      sig { params(assets_dir: String).returns(T::Array[Asset]) }
      def generate_assets(assets_dir)
        if type = self.type
          type.generate_assets(assets_dir)
        else
          []
        end
      end

      sig { returns(String) }
      def app_root = @registry.root

      sig { returns(String) }
      def absolute_path = @registry.absolute_path(@path)

      sig { returns(T.untyped) }
      def type
        @type || load_type
      end

      sig { returns(T.untyped) }
      def load_type
        @content_hash = nil
        @wrapper.__replace_impl!(
          @type =
            if exists?
              Types.for_path(self.path).new(self)
            else
              Types::Nil.new(self)
            end
        )
      end

      sig { params(path: String).returns(T.untyped) }
      def import(path)
        resource = self.registry.load_resource(path, File.dirname(self.path))
        self.registry.dependency_graph.add_dependency(self.path, resource.path)
        resource.type
      end

      MarshalFormat =
        T.type_alias do
          [String, String, T.nilable(String), Resources::Types::Base]
        end

      sig { returns(MarshalFormat) }
      def marshal_dump
        if exists?
          [path, path_hash, content_hash, type]
        else
          [path, path_hash, nil, type]
        end
      end

      sig { params(args: MarshalFormat).void }
      def marshal_load(args)
        @path, @path_hash, @content_hash, @type = args
        @type.instance_variable_set(:@resource, self)
        @wrapper = Wrapper.new(@type)
      end
    end
  end
end
