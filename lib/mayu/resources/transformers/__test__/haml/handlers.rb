# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
def handle_click(e)
  Console.logger.info(self, e)
end
public def render
  Mayu::VDOM.h(
    :button,
    "Click me",
    **mayu.merge_props({ onclick: mayu.handler(:handle_click) })
  )
end
