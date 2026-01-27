# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "vchildren"
require_relative "vattributes"

module Mayu
  module Runtime
    module VNodes
      class VAttributes < Base
        def initialize(...)
          super
          @attributes = update_attributes({}, flatten_props(@descriptor.props))
        end

        def update(patches)
          @attributes = update_attributes({}, flatten_props(@descriptor.props))
        end

        def render_html(out)
          @attributes.each do |attr, value|
            value = value.join(" ") if value in Array

            out << format(
              ' %s="%s"',
              CGI.escape_html(attr.to_s.tr("_", "-")),
              if value.respond_to?(:to_js)
                value.to_js
              else
                CGI.escape_html(value.to_s)
              end
            )
            " #{key}=#{value.inspect}"
          end
        end
      end
    end
  end
end
