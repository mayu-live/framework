# typed: strict

require_relative "store"
require_relative "../app"

module Mayu
  module State
    class Selector
      module SelectorModule
        extend T::Sig

        sig do
          params(
            block: T.proc.params(state: T.untyped).returns(T.untyped)
          ).returns(Selector)
        end
        def selector(&block)
          Selector.new
        end

        sig do
          params(
            block: T.proc.params(state: T.untyped).returns(T.untyped)
          ).returns(Module)
        end
        def self.build(&block)
          mod = Module.new
          mod.send(:extend, SelectorModule)
          mod.class_eval(&block)
          mod
        end
      end

      extend T::Sig
    end

    module Actions
      module ActionModule
        extend T::Sig

        sig do
          params(
            type: Symbol,
            block: T.nilable(ActionCreator::PreparedActionCreator::ProcType)
          ).returns(ActionCreator::Base)
        end
        def action(type, &block)
          ActionCreator.create(type, &block)
        end

        sig do
          params(
            type: Symbol,
            block: ActionCreator::AsyncActionCreator::ProcType
          ).returns(ActionCreator::AsyncActionCreator)
        end
        def async(type, &block)
          ActionCreator.async(type, &block)
        end

        sig do
          params(
            block: T.proc.params(state: T.untyped).returns(T.untyped)
          ).returns(Module)
        end
        def self.build(&block)
          mod = Module.new
          mod.send(:extend, ActionModule)
          mod.class_eval(&block)
          mod
        end
      end

      extend T::Sig
    end

    module ReducerDSL
      extend T::Sig
      extend T::Helpers
      interface!

      sig { abstract.params(kwargs: T.untyped).void }
      def initial_state(**kwargs)
      end

      sig do
        abstract
          .params(action: ActionCreator::Base, reducer: Store::Reducer)
          .void
      end
      def reducer(action, &reducer)
      end

      sig { abstract.params(url: String, options: T.untyped).void }
      def fetch(url, **options)
      end

      sig do
        abstract
          .params(
            block:
              T.proc.bind(Selector::SelectorModule).params(arg0: T.untyped).void
          )
          .returns(Module)
      end
      def selectors(&block)
      end

      sig do
        abstract
          .params(
            block:
              T.proc.bind(Actions::ActionModule).params(arg0: T.untyped).void
          )
          .returns(Module)
      end
      def actions(&block)
      end
    end

    class Loader
      extend T::Sig

      class ReducerBuilder
        extend ::T::Sig
        include ::Mayu::State::ReducerDSL

        sig do
          params(source: ::String, path: ::String).returns(
            T::Hash[Symbol, T.untyped]
          )
        end
        def self.build(source, path)
          { initial_state: nil, reducers: [], actions: [] }.tap do
            new(File.basename(path, ".*"), _1).instance_eval(source, path, 0)
          end
        end

        sig { params(prefix: String, data: T::Hash[::Symbol, T.untyped]).void }
        def initialize(prefix, data)
          @prefix = prefix
          @data = data
        end

        sig { override.params(kwargs: T.untyped).void }
        def initial_state(**kwargs)
          @data[:initial_state] = kwargs
        end

        sig { override.params(url: String, options: T.untyped).void }
        def fetch(url, **options)
        end

        sig do
          override
            .params(
              block:
                T
                  .proc
                  .bind(Selector::SelectorModule)
                  .params(arg0: T.untyped)
                  .void
            )
            .returns(Module)
        end
        def selectors(&block)
          @data[:selectors] = Selector::SelectorModule.build(&block)
        end

        sig do
          override
            .params(
              block:
                T.proc.bind(Actions::ActionModule).params(arg0: T.untyped).void
            )
            .returns(Module)
        end
        def actions(&block)
          @data[:actions] = Actions::ActionModule.build(&block)
        end

        sig do
          override
            .params(action: ActionCreator::Base, reducer: Store::Reducer)
            .void
        end
        def reducer(action, &reducer)
          @data[:reducers].push([action, reducer])
        end
      end

      sig { params(directory: String).void }
      def initialize(directory)
        @directory = directory
      end

      sig { returns(Store::Reducers) }
      def load
        Dir[File.join(@directory, "*.rb")]
          .map do |path|
            data = ReducerBuilder.build(File.read(path), path)
            name = File.basename(path, ".*").capitalize.to_sym

            Mayu::App.replace_module(
              name,
              Actions: data[:action_module],
              Selectors: data[:selector_module]
            )

            [
              name,
              ->(state, action) do
                state ||= data[:initial_state]

                data[:reducers]
                  .filter { _1 === action }
                  .reduce(
                    state || data[:initial_state]
                  ) { |state, (_, reducer)| reducer.call(state, action) }
              end
            ]
          end
          .to_h
      end
    end
  end
end
