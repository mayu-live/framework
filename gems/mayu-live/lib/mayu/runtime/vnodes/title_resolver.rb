# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module Runtime
    module VNodes
      # Resolves the document title from every registered head node.
      #
      # The deepest %title wins. Every other %title with a template attribute
      # that sits above it in the tree wraps it, innermost first:
      #
      #   %title(template="%s | Acme") Acme   -# root
      #   %title(template="%s | Blog") Blog   -# layout
      #   %title Hello                        -# page
      #
      # gives "Hello | Blog | Acme". A title's own template never applies to
      # itself, so the text of a templated title works as the default.
      # %title(absolute) opts out of every template above it.
      module TitleResolver
        def self.call(heads)
          titled = heads.filter_map { |head| (title = head.title) && [head, title] }
          return if titled.empty?

          leaf, leaf_title =
            titled.each_with_index.max_by { |(head, _), index| [head.depth, index] }.first

          return text_of(leaf_title) if leaf_title.props[:absolute]

          titled
            .select do |head, title|
              head != leaf && title.props[:template] && leaf.within?(head.scope)
            end
            .sort_by { |head, _| -head.depth }
            .reduce(text_of(leaf_title)) do |text, (_, title)|
              title.props[:template].to_s.gsub("%s") { text }
            end
        end

        def self.text_of(title)
          Array(title.children).flatten.grep(String).join
        end
      end
    end
  end
end
