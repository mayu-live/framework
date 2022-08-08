render do
  h.div do
    h.h1 "About"
    h.ul do
      h.li "Mayu is a VDOM implementation in Ruby."
      h.li "DOM updates are streamed to the browser."
      h.li "Nested layouts and dynamic routes."
      h.li "Event handlers run on the server, there is no need for APIs."
      h.li "Only the required CSS is loaded on each page."
      h.li "JSX-inspired syntax."
      h.li "Hot reloading in development."
      h.li "Designed to be deployed near users."
    end.ul
  end.div
end
