# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "cgi"
require_relative "patches"
require_relative "inline_style"

module Mayu
  module Runtime
    module DOM
      INJECT_MAYU_ID = false

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
            if c = children
              { id:, name:, children: c.flatten.compact.map(&:serialize) }
            else
              { id:, name: }
            end
          end

          def to_msgpack(packer)
            packer.pack(serialize)
          end
        end

      Document =
        Data.define(:id, :children) do
          def self.[](*children, id:)
            new(id, children.flatten)
          end

          def type = "#document"
          def text_content
            children.map(&:text_content)
          end

          def to_html
            "<!DOCTYPE html>\n#{children.map(&:to_html).join}\n"
          end

          def id_node
            IdNode[id, type, children.map(&:id_node)]
          end

          def patch_insert
            Patches::Initialize[id_node]
          end

          def traverse(&block)
            yield self
            children.each { |child| child.traverse(&block) }
            nil
          end

          def find(&block)
            traverse do |node|
              return node if yield node
            end
          end
        end

      Element =
        Data.define(:name, :id, :children, :attributes) do
          def self.[](id, type, *children, **attributes)
            new(type, id, children.flatten.compact, attributes)
          end

          def type = name.to_s
          def text_content
            children.map(&:text_content).join
          end

          def to_html
            attrs =
              attributes
                .except(:slot)
                .then { {**internal_attributes, **_1} }
                .map do |attr, value|
                  if attr == :style && value in Hash
                    value = InlineStyle.stringify(value)
                  end

                  format(
                    ' %s="%s"',
                    CGI.escape_html(attr.to_s.tr("_", "-")),
                    if value.respond_to?(:to_js)
                      value.to_js
                    else
                      CGI.escape_html(value.to_s)
                    end
                  )
                end
                .join

            if VOID_ELEMENTS.include?(name)
              "<#{name}#{attrs}>"
            else
              rendered_children = children.map(&:to_html).join
              "<#{name}#{attrs}>#{rendered_children}</#{name}>"
            end
          end

          def id_node
            IdNode[id, name.upcase, children.map(&:id_node)]
          end

          def patch_insert
            Patches::CreateTree[to_html, id_node]
          end

          def patch_remove = Patches::RemoveNode[id]

          def traverse(&block)
            yield self
            children.each { |child| child.traverse(&block) }
            nil
          end

          def find(&block)
            traverse do |node|
              return node if yield node
            end
          end

          private

          def internal_attributes
            if INJECT_MAYU_ID
              { mayu_id: id }
            else
              {}
            end
          end
        end

      Text =
        Data.define(:id, :content) do
          def text_content = content.to_s

          def type = "#text"
          def to_html = CGI.escape_html(content.to_s)
          def id_node = IdNode[id, type]

          def patch_insert = Patches::CreateTextNode[id, content]
          def patch_remove = Patches::RemoveNode[id]

          def traverse
            yield self
            nil
          end

          def find(&block)
            traverse do |node|
              return node if yield node
            end
          end
        end

      Comment =
        Data.define(:id, :content) do
          def type = "#comment"
          def text_content = ""
          def to_html = "<!--#{escape_comment(content)}-->"
          def id_node = IdNode[id, type]

          def patch_insert = Patches::CreateComment[id, content]
          def patch_remove = Patches::RemoveNode[id]

          def traverse
            yield self
            nil
          end

          private

          def escape_comment(str) = str.to_s.gsub(/--/, "&#45;&#45;")

          def find(&block)
            traverse do |node|
              return node if yield node
            end
          end
        end
    end
  end
end
