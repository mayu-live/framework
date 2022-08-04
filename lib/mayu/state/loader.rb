# typed: strict

require_relative "store"

module Mayu
  module State
    module ReducerDSL
      extend T::Sig
      extend T::Helpers
      interface!

      sig { abstract.params(kwargs: T.untyped).void }
      def initial_state(**kwargs)
      end

      sig do
        abstract.params(action: ActionCreator, reducer: Store::Reducer).void
      end
      def reducer(action, &reducer)
      end

      sig do
        abstract
          .params(
            type: Symbol,
            block: T.nilable(ActionCreator::PreparedActionCreator::ProcType)
          )
          .void
      end
      def action(type, &block)
      end

      sig do
        abstract
          .params(url: String, options: T.untyped)
          .void
      end
      def fetch(url, **options)
      end

      sig do
        abstract
          .params(
            type: Symbol,
            block: ActionCreator::AsyncActionCreator::ProcType
          )
          .returns(ActionCreator::AsyncActionCreator)
      end
      def async_action(type, &block)
      end
    end

    class Loader
      extend T::Sig

      class ReducerBuilder < BasicObject
        extend ::T::Sig
        include ::Mayu::State::ReducerDSL

        sig do
          params(source: String, path: String).returns(
            T::Hash[Symbol, T.untyped]
          )
        end
        def self.build(source, path)
          { initial_state: nil, reducers: [] }.tap do
            new(_1).instance_eval(source, path, 0)
          end
        end

        sig { params(data: T::Hash[Symbol, T.untyped]).void }
        def initialize(data)
          @data = data
        end

        sig { override.params(kwargs: T.untyped).void }
        def initial_state(**kwargs)
          @data[:initial_state] = kwargs
        end

        sig do
          override
            .params(
              type: Symbol,
              block:
                T.nilable(
                  ::Mayu::State::ActionCreator::PreparedActionCreator::ProcType
                )
            )
            .void
        end
        def action(type, &block)
          @data[:actions].push(
            ::Mayu::State::ActionCreator.create(type, &block)
          )
        end

        sig do
          override
            .params(
              type: Symbol,
              block: ::Mayu::State::ActionCreator::AsyncActionCreator::ProcType
            )
            .returns(::Mayu::State::ActionCreator::AsyncActionCreator)
        end
        def async_action(type, &block)
          @data[:actions].push(::Mayu::State::ActionCreator.async(type, &block))
        end

        sig do
          override.params(action: ActionCreator, reducer: Store::Reducer).void
        end
        def reducer(action, &reducer)
          @data[:reducers].push([action, reducer])
        end
      end

      sig { params(directory: String).void }
      def initialize(directory)
        @directory = directory
      end

      sig { returns(T::Hash[Symbol, Store::Reducer]) }
      def load
        Dir[File.join(@directory, "*.rb")]
          .each do |path|
            data = ReducerBuilder.build(File.read(path), path)
            name =
              File.basename(path, ".*"),
              [
                ->(state, action) do
                  state ||= data[:initial_state]

                  data[:reducers]
                    .filter { _1 === action }
                    .reduce(state) do |state, (_, reducer)|
                      reducer.call(state, action)
                    end
                end
              ]
          end
          .to_h
      end
    end
  end
end
