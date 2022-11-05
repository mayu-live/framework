public def render
  if true
    return(
      begin
        Mayu::VDOM.h(:div, class: styles[:foo])
      end
    )
  end
  Mayu::VDOM.h(:div, class: styles[:bar])
end
