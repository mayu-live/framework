public def render
  begin
    if true
      begin
        return(
          begin
            Mayu::VDOM.h(:div, class: styles[:foo])
          end
        )
        nil
      end
    end
    nil
  end
  Mayu::VDOM.h(:div, class: styles[:bar])
end
