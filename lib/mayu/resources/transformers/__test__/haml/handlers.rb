def handle_click(e)
  Console.logger.info(self, e)
end

public def render
  Mayu::VDOM.h(:button, "Click me", **{ onclick: handler(:handle_click) })
end
