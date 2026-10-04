# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

        def dom_id
          @id
        end

        def collect_id_tree(ids)
          ids << Mayu::Runtime::DOM::IdNode[dom_id, "#comment"]
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
