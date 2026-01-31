# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"
require_relative "../patches"

module Mayu
  module Runtime
    module VNodes2
      class VRawText < Base
        def update(patcher, descriptor = nil)
          return unless descriptor
          return if @descriptor.to_s == descriptor.to_s
          @descriptor = descriptor
          patcher << Patches::SetTextContent[@id, @descriptor.to_s]
        end

        def write_html(out)
          out << @descriptor.to_s
        end

        def dom_id
          @id
        end

        def dom_id_tree
          Mayu::Runtime::DOM::IdNode[dom_id, "#text"]
        end

        def traverse(&block)
          yield self
        end
      end
    end
  end
end
