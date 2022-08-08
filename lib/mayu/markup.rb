# typed: strict

require_relative "markup/builder"
require_relative "markup/renderer"

module Mayu
  module Markup
    extend T::Sig

    sig do
      params(block: T.proc.bind(Builder).void).returns(T.nilable(VDOM::Descriptor))
    end
    def self.build(&block)
    end

    sig do
      params(
        component: VDOM::Component::Base,
        block: T.proc.bind(Builder).void
      ).returns(T.nilable(VDOM::Descriptor))
    end
    def self.render(component, &block)
      renderer = Renderer.new(component)
      renderer.instance_eval do
        T.bind(self, Renderer)
        return __builder.capture do
          instance_eval(&block)
        end&.first
      end
    end
  end
end
