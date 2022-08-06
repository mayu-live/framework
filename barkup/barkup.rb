# typed: true

require "bundler/setup"
require "json"
require "cgi"
require "sorbet-runtime"
require_relative "../lib/mayu/html"
require_relative "nodes"
require_relative "element_builder"

module Barkup
  extend T::Sig

  class Builder
    extend T::Sig

    attr_reader :streams

    sig {void}
    def initialize
      @streams = []
      @tag_builder = ElementBuilder.new(self)
    end

    sig{params(node: Node).returns(T.self_type)}
    def <<(node)
      @streams.last << node
      self
    end

    sig {params(text: T.nilable(String)).returns(ElementBuilder)}
    def h(text = nil)
      if text
        self << Text.new(text)
      end

      @tag_builder
    end

    def capture(&block)
      @streams.push([])
      instance_eval(&block)
      @streams.pop
    end
  end

  sig do
    params(block: T.nilable(T.proc.bind(Builder).void)).returns(T.nilable(Node))
  end
  def self.build(&block)
    Builder.new.capture(&block).first
  end
end
#
# module Hopp
#   out =
#     Barkup.build do
#       h.div class: "foo" do
#         h("hejsan")
#
#         h.pre "<span>hello</span>"
#       end
#     end
#
#   puts out
# end
