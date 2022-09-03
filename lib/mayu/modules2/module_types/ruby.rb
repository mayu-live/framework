# typed: strict

require_relative "base"

module Mayu
  module Modules2
    module ModuleTypes
      class Ruby < Base
        class ComponentBuilder
          extend T::Sig

          sig { params(klass: T.class_of(Component::Base)).void }
          def initialize(klass)
            @klass = klass
          end
        end

        sig { override.params(mod: Mod).returns(T.attached_class) }
        def self.load(mod)
          source = File.read(mod.absolute_path)

          klass =
            T.let(
              T.cast(Class.new(Component::Base), T.class_of(Component::Base)),
              T.class_of(Component::Base)
            )

          klass.__mayu_module = mod
          klass.class_eval(source, mod.path, 0)
          klass

          new(mod, klass)
        end

        sig { returns(T.class_of(Component::Base)) }
        attr_reader :klass

        sig { params(mod: Mod, klass: T.class_of(Component::Base)).void }
        def initialize(mod, klass)
          super(mod)
          @klass = klass
        end
      end
    end
  end
end
