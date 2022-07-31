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

  should_update? { |next_props, next_state| true }

  handler :rerender do |event|
    update { |state| { count: state[:count] + 1 } }
  end

  render do
    numbers = (1..10).to_a.shuffle.first(5)

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

Async do
  root = Mayu::VDOM.h(MyComponent)
  vtree = Mayu::VDOM::VTree.new(root)

  puts vtree.inspect_tree

  #puts vtree.dom.root
  vtree.render(root)
  puts vtree.inspect_tree(exclude_components: true)
  vtree.render(root)
  puts vtree.inspect_tree(exclude_components: true)
end
