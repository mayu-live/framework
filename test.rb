# typed: strict

require "bundler"
require "pry"
require "sorbet-runtime"
require_relative "lib/mayu/renderer"
require_relative "lib/mayu/renderer/vdom"
require_relative "lib/mayu/renderer/modules"
require_relative "lib/mayu/renderer/component_builder"

class MyComponent < Mayu::Renderer::VDOM::Component
  render { h(:span) { "hej" } }
end

modules =
  Mayu::Renderer::Modules.new(
    File.join(File.dirname(__FILE__), "example", "app")
  )
App =
  T.let(
    modules.load_component("App").klass,
    T.class_of(Mayu::Renderer::VDOM::Component)
  )

root = Mayu::Renderer.h(App)
vdom = Mayu::Renderer::VDOM.new(root)
puts vdom.inspect_tree
puts vdom.dom.root
vdom.render(root)
puts vdom.inspect_tree(exclude_components: true)
vdom.render(root)
puts vdom.inspect_tree(exclude_components: true)
