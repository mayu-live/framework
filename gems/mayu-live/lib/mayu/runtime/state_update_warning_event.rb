# frozen_string_literal: true

require "console/event/generic"

require_relative "state_update_warning_formatter"

module Mayu
  module Runtime
    class StateUpdateWarningEvent < Console::Event::Generic
      TYPE = :"mayu.state_update_during_render"

      def self.for(component, path:, line:, provider: nil)
        error = RuntimeError.new
        error.set_backtrace(["#{path}:#{line}:in 'render'"])
        if provider.respond_to?(:rewrite_exception)
          provider.rewrite_exception(error)
        end

        if provider.respond_to?(:source_location)
          source_location = provider.source_location(error)
        end
        sources = provider.source_excerpts(error) if provider.respond_to?(:source_excerpts)

        new(
          location: location_for(component, path, line, source_location, provider),
          sources: sources || []
        )
      end

      def self.location_for(component, path, line, source_location, provider)
        return "#{source_location[:file]}:#{source_location[:line]}" if source_location

        module_path = component.class.module_path if component.class.respond_to?(:module_path)
        module_id = provider.module_id_for(module_path) if
          module_path && provider.respond_to?(:module_id_for)
        module_id ||= app_module_id(module_path)
        return module_id if module_id

        "#{path}:#{line}"
      rescue KeyError, ArgumentError
        "#{path}:#{line}"
      end

      def self.app_module_id(path)
        path = path.to_s
        return if path.empty?
        return path if path.start_with?("app:/")

        relative_path = path.split("/app/").last
        "app:/#{relative_path}" unless relative_path.equal?(path)
      end

      def initialize(location:, sources:)
        @location = location
        @sources = sources
      end

      def to_hash
        {
          type: TYPE,
          location: @location,
          sources: @sources
        }
      end
    end
  end
end
