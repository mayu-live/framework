# typed: strict

require "bundler"
require "pry"
require "sorbet-runtime"
require_relative "lib/mayu/vdom"
require_relative "lib/mayu/vdom/vtree"
require_relative "lib/mayu/vdom/component"
require_relative "lib/mayu/modules/system"

class MyComponent < Mayu::VDOM::Component::Base
  extend T::Sig

  sig { override.returns(T.nilable(Mayu::VDOM::Descriptor::Children)) }
  def render
    h(:span) { "hej" }
  end
end

modules =
  Mayu::Modules::System.new(File.join(File.dirname(__FILE__), "example", "app"))

App =
  T.let(
    modules.load_component("App").klass,
    T.class_of(Mayu::VDOM::Component::Base)
  )

root = Mayu::VDOM.h(App)
vtree = Mayu::VDOM::VTree.new(root)

puts vtree.inspect_tree

#puts vtree.dom.root
vtree.render(root)
puts vtree.inspect_tree(exclude_components: true)
vtree.render(root)
puts vtree.inspect_tree(exclude_components: true)
