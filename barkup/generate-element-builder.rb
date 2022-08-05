# typed: true

require "bundler/setup"
require "json"
require "cgi"
require "sorbet-runtime"
require_relative "../lib/mayu/html"

puts "# typed: strict"
puts
puts <<EOF
module Barkup
  class ElementBuilder < BasicObject
    Element = ::Barkup::Element
    Builder = ::Barkup::Builder
    T = ::T

    extend T::Sig

    BooleanValue = ::T.type_alias { ::T.nilable(::T::Boolean) }
    Value = ::T.type_alias { ::T.nilable(::T.any(::String, ::Numeric, ::T::Boolean)) }
    EventHandler = ::T.type_alias { ::T.nilable(::T.proc.void) }

    sig {params(builder: Builder).void}
    def initialize(builder)
      @builder = builder
    end

    sig {params(klass: ::T.untyped).returns(::T::Boolean)}
    def is_a?(klass)
      ::Object.instance_method(:is_a?).bind(self).call(klass)
    end
EOF
puts
Mayu::HTML::TAGS.each do |tag|
  if Mayu::HTML.void_tag?(tag)
    puts "    sig {params(attributes: ::T.untyped).void}"
    puts "    def #{tag}(**attributes) = void!(:#{tag}, **attributes)"
  else
    puts "    sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}"
    puts "    def #{tag}(*children, **attributes, &block)= tag!(:#{tag}, children, **attributes, &block)"
  end

  puts
end

puts <<EOF
    private

    sig {params(tag: ::Symbol, attributes: ::T.untyped).void}
    def void!(tag, **attributes)
      @builder << Element.new(tag, attributes.filter { _2 }, [])
    end

    sig {params(tag: ::Symbol, children: ::T::Array[::T.untyped], attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
    def tag!(tag, children, **attributes, &block)
      children = (children + (block ? @builder.capture(&block) : [])).map do
        Element.or_text(_1)
      end
      @builder << Element.new(tag, attributes.filter { _2 }, children)
    end
  end
end
EOF
