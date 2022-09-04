#!/usr/bin/env ruby
# typed: true

raise "#{$0} is meant to be run as a script" unless $0 == __FILE__

require "bundler/setup"
require "sorbet-runtime"
require_relative "../html"

def camelize(str)
  str.to_s.capitalize.gsub(/_(\w)/) { $1.upcase }
end

class Writer
  def initialize(io)
    @io = io
    @level = 0
  end

  def puts(str = "")
    indent = "  " * @level
    @io.puts(str.gsub(/^/, indent).gsub(/\s+$/, ""))
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
  writer << <<~EOF
    # typed: strict

    # DO NOT EDIT! THIS FILE IS GENERATED AUTOMATICALLY.
    # If you want to change it, update `generate.rb` instead.

  EOF

  writer.block "module Mayu" do
    writer.block "module Markup" do
      writer.block "module Generated" do
        writer.block "module BuilderInterface" do
          writer << <<~EOF
            extend T::Sig
            extend T::Helpers
            interface!

            sig do
              abstract
                .params(
                  type: VDOM::Descriptor::ElementType,
                  children: T::Array[VDOM::Descriptor::ChildType],
                  props: T::Hash[Symbol, T.untyped],
                  block: T.nilable(T.proc.void),
                ).returns(VDOM::Descriptor)
            end
            def create_element(type, children, props, &block)
            end
          EOF
        end

        writer.block "module DescriptorBuilders" do
          writer << <<~EOF
            extend T::Sig

            include BuilderInterface

            BooleanValue = T.type_alias { T.nilable(T::Boolean) }
            Value = T.type_alias { T.nilable(T.any(::String, ::Numeric, T::Boolean)) }
            EventHandler = T.type_alias { T.nilable(T.proc.void) }

          EOF

          Mayu::HTML::TAGS.each do |tag|
            Mayu::HTML.void_tag?(tag) ? writer << <<~EOF : writer << <<~EOF
                sig {params(attributes: T.untyped).void}
                def #{tag}(**attributes) = void!(:#{tag}, **attributes)

              EOF
                sig do
                  params(
                    children: T.untyped,
                    attributes: T.untyped,
                    block: T.nilable(T.proc.void),
                  ).returns(VDOM::Descriptor)
                end
                def #{tag}(*children, **attributes, &block)
                  tag!(:#{tag}, children, **attributes, &block)
                end

              EOF
          end

          writer << <<~EOF
            private

            sig {params(tag: ::Symbol, attributes: T.untyped).returns(VDOM::Descriptor)}
            def void!(tag, **attributes)
              create_element(tag, [], attributes)
            end

            sig {params(tag: ::Symbol, children: T::Array[T.untyped], attributes: T.untyped, block: T.nilable(T.proc.void)).returns(VDOM::Descriptor)}
            def tag!(tag, children, **attributes, &block)
              create_element(tag, children, attributes, &block)
            end
          EOF
        end
      end
    end
  end
end

filename = File.join(__dir__, "descriptor_builder.rb")
puts "Generating #{filename}"
File.open(filename, "w") { |f| generate_file(Writer.new(f)) }
puts "Prettifying #{filename}"
system("npx", "prettier", "-w", filename)
