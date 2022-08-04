# typed: strict

require "nanoid"

module Mayu
  module State
    module ActionCreator
      extend T::Sig

      class Base
        extend T::Sig

        sig { returns(Symbol) }
        attr_reader :type

        sig { params(type: Symbol).void }
        def initialize(type)
          @type = type
        end

        sig { params(payload: T.untyped).returns(Store::ActionHash) }
        def call(payload = nil)
          { type:, payload: }
        end

        sig { params(other: T.untyped).returns(T::Boolean) }
        def ===(other)
          case other
          when Hash
            @type == other[:type]
          when ActionWrapper
            @type == other.type
          else
            super
          end
        end
      end

      class StaticActionCreator < Base
      end

      class PreparedActionCreator < Base
        ProcType = T.type_alias { T.proc.returns(Store::ActionHash) }

        sig do
          params(type: Symbol, block: T.proc.returns(Store::ActionHash)).void
        end
        def initialize(type, &block)
          super(type)
          @prepare = block
        end

        sig do
          params(args: T.untyped, kwargs: T.untyped).returns(Store::ActionHash)
        end
        def call(*args, **kwargs)
          { type: }.merge(T.unsafe(@prepare).call(*args, **kwargs))
        end
      end

      class AsyncActionCreator < Base
        ProcType =
          T.type_alias do
            T.proc.params(arg0: Store, args: T.untyped, kwargs: T.untyped).void
          end

        sig { returns(StaticActionCreator) }
        attr_reader :pending
        sig { returns(StaticActionCreator) }
        attr_reader :fulfilled
        sig { returns(StaticActionCreator) }
        attr_reader :rejected

        sig { params(type: Symbol, block: ProcType).void }
        def initialize(type, &block)
          super(type)
          @block = block
          @pending =
            T.let(
              StaticActionCreator.new(:"#{type}/pending"),
              StaticActionCreator
            )
          @fulfilled =
            T.let(
              StaticActionCreator.new(:"#{type}/fulfilled"),
              StaticActionCreator
            )
          @rejected =
            T.let(
              StaticActionCreator.new(:"#{type}/rejected"),
              StaticActionCreator
            )
        end

        sig do
          params(
            args: T.untyped,
            parent: Async::Task,
            kwargs: T.untyped
          ).returns(Store::Thunk)
        end
        def call(*args, parent: Async::Task.current, **kwargs)
          ->(store) do
            parent.async do |task|
              request_id = Nanoid.generate()
              store.dispatch(pending, *args, **kwargs.merge(request_id:))
              result =
                T.unsafe(@block).call(store, *args, **kwargs.merge(task:, request_id:))
              store.dispatch(fulfilled, result)
            rescue => error
              store.dispatch(rejected, { error:, request_id: })
            end
          end
        end
      end

      module ActionContext
        extend T::Sig

        FetchResponse = T.type_alias { String }
        Header = T.type_alias { [String, String] }

        sig do
          params(
            resource: T.any(String, URI),
            method: Symbol,
            headers: T::Array[Header],
            body: T.nilable(String),
            redirect: Symbol,
            referrer: String,
            keepalive: T::Boolean
          ).returns(FetchResponse)
        end
        def fetch(
          resource,
          method: :GET,
          headers: [],
          body: nil,
          redirect: :follow,
          referrer: "mayu-live-fetch/#{Mayu::VERSION}",
          keepalive: false
        )
          internet = Async::HTTP::Internet.new

          case method
          when :GET
            internet.get(resource, headers)
          when :POST
            internet.post(resource, headers, body)
          when :PUT
            internet.put(resource, headers, body)
          when :PATCH
            internet.patch(resource, headers, body)
          end
        ensure
          internet&.close
        end
      end

      sig do
        params(
          type: Symbol,
          block: T.nilable(PreparedActionCreator::ProcType)
        ).returns(Base)
      end
      def self.create(type, &block)
        if block_given?
          PreparedActionCreator.new(type, &block)
        else
          StaticActionCreator.new(type)
        end
      end

      sig do
        params(type: Symbol, block: AsyncActionCreator::ProcType).returns(
          AsyncActionCreator
        )
      end
      def self.async(type, &block)
        AsyncActionCreator.new(type, &block)
      end
    end
  end
end
