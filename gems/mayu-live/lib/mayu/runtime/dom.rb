# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module Runtime
    module DOM
      INJECT_MAYU_ID = ENV["INJECT_MAYU_ID"] == "1"

      VOID_ELEMENTS = %w[
        area
        base
        br
        col
        embed
        hr
        img
        input
        link
        meta
        param
        source
        track
        wbr
      ].freeze

      IdNode =
        Data.define(:id, :name, :children) do
          def self.[](id, name, children = nil)
            new(id, name, children)
          end

          def inspect
            format("%s#%s%s", name, id, (children || []).inspect)
          end

          def pretty_print(q)
            color = name.start_with?("#") ? "36" : "34"

            q.group(
              1,
              "#{"  " * q.indent}\e[1;#{color}m#{name}\e[0;2m #{id}\e[0m\n"
            ) { children&.each { |child| q.pp child } }
          end

          def serialize
            if (c = children)
              {id:, name:, children: c.map(&:serialize)}
            else
              {id:, name:}
            end
          end

          # The same map as #serialize, written straight to the packer.
          def to_msgpack(packer)
            c = children
            packer.write_map_header(c ? 3 : 2)
            packer.write("id")
            packer.write(id)
            packer.write("name")
            packer.write(name)

            if c
              packer.write("children")
              packer.write_array_header(c.length)
              c.each { |child| child.to_msgpack(packer) }
            end

            packer
          end
        end
    end
  end
end
