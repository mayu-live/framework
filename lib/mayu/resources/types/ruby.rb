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

          klass.__mayu_resource = resource
          klass.class_eval(source, resource.path, 0)

          styles = resource.system.load_css(resource)

          klass.define_singleton_method(:stylesheet) { styles.type } if styles

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
