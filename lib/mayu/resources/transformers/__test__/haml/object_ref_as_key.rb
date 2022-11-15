public def render
  Mayu::VDOM.h(:div, key: ["hello"].inspect)
end
