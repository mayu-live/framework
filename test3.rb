# typed: false

require "async"
require "bundler"
require "pry"
require "sorbet-runtime"
require_relative "lib/mayu/vdom"
require_relative "lib/mayu/vdom/vtree"
require_relative "lib/mayu/vdom/component"
require_relative "lib/mayu/modules/system"

class MyComponent < Mayu::VDOM::Component::Base
  extend T::Sig

  initial_state { |props| { count: 0 } }

  should_update? { |next_props, next_state|
    return true
    unless props == next_props
      return true
    end
    unless state == next_state
      return true
    end
    false
  }

  handler :rerender do |event|
    update { |state| { count: state[:count] + 1 } }
  end

  render do
    numbers = (1..10).to_a.shuffle.first(5 + rand(3))

    items = numbers.map { |i| h(:li, key: i) { i.to_s } }

    h(:div) do
      [
        h(:button, on_click: handler(:rerender)) { "Rerender" },
        h(:p) { "numbers: #{numbers.inspect}" },
        h(:ul) { items }
      ]
    end
  end
end

require "rexml/document"
require "stringio"

def format2(source)
  io = StringIO.new
  doc = REXML::Document.new(source)
  formatter = REXML::Formatters::Pretty.new
  formatter.compact = true
  formatter.write(doc, io)
  io.rewind
  puts io.read.gsub(/(mayu-id='?)(\d+)/) { "#{$~[1]}\e[7m#{$~[2]}\e[0m" }
end

Async do |task|
  Random.srand(ARGV.first.to_i)
  root = Mayu::VDOM.h(MyComponent)
  vtree = Mayu::VDOM::VTree.new(root, task:)

  puts vtree.inspect_tree

  #puts vtree.dom.root
  vtree.render(root)
  format2(vtree.inspect_tree(exclude_components: true))
  puts
  puts "rerender"
  vtree.render(root)
  format2(vtree.inspect_tree(exclude_components: true))

  task.stop
end
