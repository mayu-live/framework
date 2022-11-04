public def render
  begin
    name = "foo"
    nil
  end
  Mayu::VDOM.slot(children, name) ||
    begin
      Mayu::VDOM.h(:p, "Fallback content")
    end
end
