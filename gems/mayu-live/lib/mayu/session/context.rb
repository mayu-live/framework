# frozen_string_literal: true

require "protocol/http/response"
require_relative "../request_origin"

module Mayu
  class Session
    Preparation = Data.define(:context, :headers) do
      def self.redirect(location, status: 303)
        Protocol::HTTP::Response[status, {"location" => location}]
      end

      def initialize(context: {}, headers: [])
        super
      end
    end

    Info = Data.define(:id, :path, :context, :origin) do
      def initialize(id:, path:, context:, origin:)
        super(id: id.dup.freeze, path: path.dup.freeze, context: Context.snapshot(context), origin: RequestOrigin.normalize(origin))
      end
    end

    class Rejected < StandardError
      attr_reader :location

      def initialize(location: nil)
        @location = location&.dup&.freeze
        super("Application session rejected")
      end
    end

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
