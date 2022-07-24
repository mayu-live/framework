# typed: strict

require "bundler"
require "sorbet-runtime"
require_relative "vdom"
require_relative "modules"
require_relative "component_builder"
require_relative "../renderer"

class MyComponent < Mayu::Renderer::VDOM::Component
  render do
    h(:span) do
      "hej"
    end
  end
end

modules = Mayu::Renderer::Modules.new(File.join(File.dirname(__FILE__), "components"))
App = T.let(modules.load_component('App'), T.class_of(Mayu::Renderer::VDOM::Component))

root = Mayu::Renderer.h(App)
vdom = Mayu::Renderer::VDOM.new(root)
puts vdom.inspect_tree
puts vdom.dom.root
vdom.render(root)
puts vdom.inspect_tree
