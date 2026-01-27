# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"

module Mayu
  module Runtime
    module VNodes
      class VComponent < Base
        def initialize(...)
          super

          klass = @descriptor.type

          if mod = get_mod
            vdocument = closest(VDocument)

            find_stylesheets(mod).each do |filename|
              vdocument.add_stylesheet(filename)
            end
          end

          @instance = klass.allocate
          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )
          @instance.send(:initialize)
          @children = VChildren.new(render_children, parent: self)
        end

        def start
          @parent.task.async {}
        end

        def stop
        end
      end
    end
  end
end
