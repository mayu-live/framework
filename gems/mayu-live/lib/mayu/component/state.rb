# frozen_string_literal: true

module Mayu
  module Component
    # The state receiver used by Klenod's Haml variable rewriting. Its owner is
    # deliberately transient: only values are serialized with a live session.
    class State
      def initialize(owner = nil, values: {})
        @owner = owner
        @values = values
      end

      def [](key)
        @values[key]
      end

      def []=(key, value)
        @values[key] = value
        @owner&.send(:update!, value)
      end

      def bind(owner)
        @owner = owner
        self
      end

      def marshal_dump
        @values
      end

      def marshal_load(values)
        @values = values
        @owner = nil
      end
    end
  end
end
