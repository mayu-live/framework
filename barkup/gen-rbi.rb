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

    extend ::T::Sig

    BooleanValue = ::T.type_alias { ::T.nilable(::T::Boolean) }
    Value = ::T.type_alias { ::T.nilable(::T.any(::String, ::Numeric, ::T::Boolean)) }
    EventHandler = ::T.type_alias { ::T.nilable(::T.proc.void) }

    sig {params(builder: Builder).void}
    def initialize(builder)
    end

    sig {params(klass: ::T.untyped).returns(::T::Boolean)}
    def is_a?(klass)
    end
EOF
puts
Mayu::HTML::TAGS.each do |tag|
  next unless %i[div p button a].include?(tag)
  supported_attributes = Mayu::HTML.attributes_for(tag)
    .map { |attr| attr.to_s.gsub("-", "_").to_sym }

  attribute_types =
    supported_attributes
      .map do |attr|
        if Mayu::HTML.boolean_attribute?(attr)
          "#{attr}: BooleanValue, "
        elsif Mayu::HTML.event_handler_attribute?(attr)
          "#{attr}: EventHandler, "
        else
          "#{attr}: Value, "
        end
      end
      .join

  attribute_defaults =
    supported_attributes
      .map do |attr|
        if Mayu::HTML.boolean_attribute?(attr)
          "#{attr}: false, "
        else
          "#{attr}: nil, "
        end
      end
      .join

  attribute_pass = supported_attributes.map { |attr| "#{attr}:, " }.join

  if Mayu::HTML.void_tag?(tag)
    puts "  sig {params(#{attribute_types}attributes: ::T.untyped).void}"
    puts "  def #{tag}(#{attribute_defaults}**attributes)"
    puts "  end"
  else
    puts "  sig {params(children: ::T.untyped, #{attribute_types}attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}"
    puts "  def #{tag}(*children, #{attribute_defaults}**attributes, &block)"
    puts "  end"
  end
  puts
end
puts "end"
puts "end"
