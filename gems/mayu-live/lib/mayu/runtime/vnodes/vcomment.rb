# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../dom"

require_relative "base"

module Mayu
  module Runtime
    module VNodes
      class VComment < Base
        def update(_command_collector, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
        end

        def write_html(out)
          out << "<!--#{escape_comment(@descriptor.to_s)}-->"
        end

        def write_html_with_id_tree(out)
          write_html(out)
          dom_id_tree
        end

        def dom_id
          @id
        end

        def dom_id_tree
          Mayu::Runtime::DOM::IdNode[dom_id, "#comment"]
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

        private

        def escape_comment(str)
          str.to_s.gsub("--", "&#45;&#45;")
        end
      end
    end
  end
end
