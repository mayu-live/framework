# frozen_string_literal: true

module Mayu
  class Session
    Preparation = Data.define(:context, :headers) do
      def initialize(context: {}, headers: [])
        super
      end
    end

    Info = Data.define(:id, :path, :context)

    module Context
      def self.snapshot(value)
        unless value.instance_of?(Hash) && value.keys.all? { it.is_a?(Symbol) }
          raise ArgumentError, "Session context must be a symbol-keyed hash"
        end
        copy(value)
      end

      def self.copy(value, ancestors = [])
        raise ArgumentError, "Cyclic session context" if ancestors.any? { it.equal?(value) }

        case value
        when Hash
          value.to_h { |key, item| [copy(key, [*ancestors, value]), copy(item, [*ancestors, value])] }.freeze
        when Array
          value.map { copy(it, [*ancestors, value]) }.freeze
        when String
          value.dup.freeze
        when Symbol, Integer, true, false, nil
          value
        when Float
          raise ArgumentError, "Non-finite session context number" unless value.finite?
          value
        else
          raise ArgumentError, "Unsupported session context value: #{value.class}"
        end
      end
    end
  end
end
