# typed: strict

require_relative "base"

module Mayu
  module Modules2
    module ModuleTypes
      class Ruby < Base
        class ComponentBuilder
          extend T::Sig

          class << self
            extend T::Sig

            sig { params(__mayu_module: Mod).void }
            attr_writer :__mayu_module

            sig { returns(Mod) }
            def __mayu_module
              @__mayu_module or raise "__mayu_module is not set"
            end

            sig { void }
            def initialize
              # This method will never be called, but will make Sorbet happy..
              @__mayu_module = T.let(nil, T.nilable(Mod))
            end
          end

          def import(path)
            self.class.__mayu_module.load_relative(path) => mod
            mod.type => ModuleTypes::Ruby => ruby
            ruby.klass
          end
        end

        sig { override.params(mod: Mod).returns(T.attached_class) }
        def self.load(mod)
          source = File.read(mod.absolute_path)

          klass =
            T.let(
              T.cast(Class.new(ComponentBuilder), T.class_of(ComponentBuilder)),
              T.class_of(ComponentBuilder)
            )

          klass.__mayu_module = mod
          klass.class_eval(source, mod.path, 0)
          klass
          new(mod, klass)
        end

        sig { returns(T.class_of(VDOM::Component::Base)) }
        attr_reader :klass

        sig { params(mod: Mod, klass: T.class_of(VDOM::Component::Base)).void }
        def initialize(mod, klass)
          super(mod)
          @klass = klass
        end
      end
    end
  end
end
