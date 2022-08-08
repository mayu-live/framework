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
  writer << "require_relative 'unclosed_element'"
  writer << ""
  writer.block "module Mayu" do
    writer.block "module Markup" do
      writer.block "module Generated" do
        writer.block "module UnclosedElements" do
          Mayu::HTML::TAGS.each do |tag|
            next if Mayu::HTML.void_tag?(tag)

            writer.block "class #{camelize(tag)} < UnclosedElement" do
              writer.puts "sig {returns(::Mayu::VDOM::Descriptor)}; def #{tag} = @descriptor"
            end
          end
        end

        writer.block "module BuilderInterface" do
          writer << <<~EOF
            extend T::Sig
            extend T::Helpers
            interface!

            sig{abstract.params(type: VDOM::Descriptor::ElementType, children: T::Array[VDOM::Descriptor::ChildType], props: T::Hash[Symbol, T.untyped], block: T.nilable(T.proc.void)).returns(VDOM::Descriptor)}
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
            if Mayu::HTML.void_tag?(tag)
              writer.puts "sig {params(attributes: T.untyped).void}"
              writer.puts "def #{tag}(**attributes) = void!(:#{tag}, **attributes)"
            else
              writer.puts "sig {params(children: T.untyped, attributes: T.untyped, block: T.nilable(T.proc.void)).returns(UnclosedElements::#{camelize(tag)})}"
              writer.block "def #{tag}(*children, **attributes, &block)" do
                writer.puts "UnclosedElements::#{camelize(tag)}.new(tag!(:#{tag}, children, **attributes, &block))"
              end
            end

            writer.puts
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

filename = "descriptor_builder.rb"

puts "Generating #{filename}"

File.open(filename, 'w') do |f|
  generate_file(Writer.new(f))
end

puts "Prettifying #{filename}"

system("npx", "prettier", "-w", filename)
