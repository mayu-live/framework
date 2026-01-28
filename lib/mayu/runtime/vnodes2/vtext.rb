# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "cgi"
require_relative "../dom"

require_relative "base"
require_relative "../patches"

module Mayu
  module Runtime
    module VNodes2
      class VText < Base
        def update(patcher, descriptor = nil)
          return unless descriptor
          return if @descriptor.to_s == descriptor.to_s
          @descriptor = descriptor
          patcher << Patches::SetTextContent[@id, @descriptor.to_s]
        end

        def write_html(out)
          content = @descriptor.to_s
          out << (
            content.empty? ? "&ZeroWidthSpace;" : CGI.escape_html(content)
          )
        end

        def dom_id
          @id
        end

        def dom_id_tree
          Mayu::Runtime::DOM::IdNode[dom_id, "#text"]
        end
      end
    end
  end
end
