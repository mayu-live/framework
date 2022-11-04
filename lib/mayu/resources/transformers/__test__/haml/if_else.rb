public def render
  if true
    Mayu::VDOM.h(:div, class: styles[:foo])
  else
    Mayu::VDOM.h(:div, class: styles[:bar])
  end
end
