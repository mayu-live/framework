public def render
  Mayu::VDOM.h(:button, "Click me", class: styles[:button])
end
