#!/usr/bin/env ruby
# typed: strict

require_relative "../markup"
require_relative "../vdom/descriptor"
require "pry"

extend T::Sig

class MyComponent
  extend T::Sig

  sig { returns(Mayu::VDOM::Descriptor) }
  def render
    h.div do
      h.h1 "Page title"

      h.table do
        h.tbody do
          h.tr do
            h.td "Item 1"
            h.td "User 1"
          end

          h.tr do
            h.td "Item 2"
            h.td "User 1"
          end

          h.tr do
            h.td "Item 3"
            h.td "User 2"
          end
        end
      end

      h.div do
        h << "Hello "
        h.span "world", style: "font-weight: bold;"
      end
    end
  end

  sig { returns(Mayu::Markup::Builder) }
  def h
    Mayu::Markup::Builder.new
  end
end

sig { params(descriptor: Mayu::VDOM::Descriptor).void }
def debug(descriptor)
  if descriptor.text?
    print descriptor.props[:text_content]
  elsif descriptor.comment?
    print "<!-- -->"
  else
    print "<#{descriptor.type.to_s}>"
    descriptor.children.each { debug(_1) }
    print "</#{descriptor.type.to_s}>"
  end
end

debug(MyComponent.new.render)
