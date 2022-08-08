#!/usr/bin/env ruby
# typed: true

unless $0 == __FILE__
  raise "#$0 is meant to be run as a script"
end

require "bundler/setup"
require "sorbet-runtime"
require_relative "../html"

def camelize(str)
  str.to_s.capitalize.gsub(/_(\w)/){$1.upcase}
end

class Writer
  def initialize(io)
    @io = io
    @level = 0
  end

  def puts(str = "")
    indent = "  " * @level
    @io.puts(str.gsub(/^/, indent).gsub(/\s+$/, ''))
    self
  end

  def <<(str)
    puts(str)
    self
  end

  def block(str, &blk)
    puts str
    indent { yield }
    puts "end"
  end

  def indent(&block)
    @level += 1
    yield
  ensure
    @level -= 1
  end
end

def generate_file(writer)
  writer << "# typed: strict"
  writer << ""
  writer.block "module Mayu" do
    writer.block "module VDOM" do
      writer.puts "class Descriptor ; end"
    end
    writer.block "module Markup" do
      writer.puts "class Builder ; end"
      writer.block "class DescriptorBuilder < BasicObject" do
        writer << <<~EOF
          Descriptor = ::Mayu::VDOM::Descriptor
          Builder = ::Mayu::Markup::Builder
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

        writer.block "module TagClosers" do
          writer.block "class BaseTagCloser < BasicObject" do
            writer << "extend ::T::Sig"
            writer << <<~EOF
              sig {params(klass: ::T.untyped).returns(::T::Boolean)}
              def is_a?(klass)
                ::Object.instance_method(:is_a?).bind(self).call(klass)
              end
            EOF
          end

          Mayu::HTML::TAGS.each do |tag|
            writer.block "class #{camelize(tag)} < BaseTagCloser" do
              writer.puts "sig {void}; def #{tag} = nil"
            end
          end
        end

        Mayu::HTML::TAGS.each do |tag|
          if Mayu::HTML.void_tag?(tag)
            writer.puts "sig {params(attributes: ::T.untyped).void}"
            writer.puts "def #{tag}(**attributes) = void!(:#{tag}, **attributes)"
          else
            writer.puts "sig {params(children: ::T.untyped, attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).returns(TagClosers::#{camelize(tag)})}"
            writer.block "def #{tag}(*children, **attributes, &block)" do
              writer.puts "tag!(:#{tag}, children, **attributes, &block)"
              writer.puts "TagClosers::#{camelize(tag)}.new"
            end
          end

          writer.puts
        end

        writer << <<~EOF
          private

          sig {params(tag: ::Symbol, attributes: ::T.untyped).void}
          def void!(tag, **attributes)
            @builder << Descriptor.new(tag, attributes.filter { _2 }, [])
          end

          sig {params(tag: ::Symbol, children: ::T::Array[::T.untyped], attributes: ::T.untyped, block: ::T.nilable(::T.proc.bind(Builder).void)).void}
          def tag!(tag, children, **attributes, &block)
            children = (children + (block ? @builder.capture(&block) : [])).map do
              Descriptor.or_text(_1)
            end
            @builder << Descriptor.new(tag, attributes.filter { _2 }, children)
          end
        EOF
      end
    end
  end
end

filename = "descriptor_builder.rb"

puts "Generating #{filename}"

File.open(filename, 'w') do |f|
  generate_file(Writer.new(f))
end

puts "Prettifying #{filename}"

system("npx", "prettier", "-w", filename)
