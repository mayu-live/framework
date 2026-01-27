# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "cgi"

require_relative "base"

module Mayu
  module Runtime
    module VNodes2
      class VText < Base
        def update(_patcher)
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
          dom_id
        end
      end
    end
  end
end
