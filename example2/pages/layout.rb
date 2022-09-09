# typed: true

def render
  h.html do
    h.head { h.meta name: "charset", value: "utf-8" }

    h.body do
      h.div do
        h.menu do
          h.li { h.a "Start page", href: "/" }
          h.li { h.a "Pokemon", href: "/pokemon" }
        end

        h << children.first
      end
    end
  end
end
