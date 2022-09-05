# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Types
      class Ruby < Base
        sig { override.params(resource: Resource).returns(T.attached_class) }
        def self.load(resource)
          source = File.read(resource.absolute_path)

          klass =
            T.let(
              T.cast(Class.new(Component::Base), T.class_of(Component::Base)),
              T.class_of(Component::Base)
            )

          klass.__mayu_module = resource
          klass.class_eval(source, resource.path, 0)
          klass

          new(resource, klass)
        end

        sig { returns(T.class_of(Component::Base)) }
        attr_reader :klass

        sig do
          params(resource: Resource, klass: T.class_of(Component::Base)).void
        end
        def initialize(resource, klass)
          super(resource)
          @klass = klass
        end
      end
    end
  end
end
