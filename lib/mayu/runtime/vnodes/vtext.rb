# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "cgi"
require_relative "../dom"

require_relative "base"
require_relative "../commands"

module Mayu
  module Runtime
    module VNodes
      class VText < Base
        def update(collector, descriptor = nil)
          return unless descriptor
          return if @descriptor.to_s == descriptor.to_s
          @descriptor = descriptor
          collector << Commands::SetTextContent[@id, @descriptor.to_s]
        end

        def write_html(out)
          content = @descriptor.to_s
          out << (
            content.empty? ? "&ZeroWidthSpace;" : CGI.escape_html(content)
          )
        end

        def write_html_with_id_tree(out)
          write_html(out)
          dom_id_tree
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

        def marshal_dump
          super
        end

        def marshal_load(a)
          super
        end
      end
    end
  end
end
