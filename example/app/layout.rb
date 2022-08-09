Header = import("Layout/Header")
Footer = import("Layout/Footer")

# stree-ignore
render do
  h.html lang: "en", class: styles.html do
    h.head do
      h.meta name: "charset", value: "utf-8"
    end.head

    h.body class: styles.body do
      h[Header]

      h.div class: styles.wrap do
        h.menu class: styles.menu do
          [
            ["Start page", "/"],
            ["Pokémon", "/pokemon"],
            ["Tree", "/tree"],
            ["Name reverser", "/name-reverser"],
            ["Counter", "/counter"],
            ["Numbers", "/numbers"],
            ["Breakout", "/breakout"],
            ["About", "/about"],
          ].each do |title, href|
            h.li class: styles.menuItem do
              h.a(title, class: styles.menuLink, href:)
            end.li
          end
        end.menu

        h.div class: styles.mainWrap do
          h.main class: styles.main do
            h << children.compact.first
          end.main
        end.div
      end.div

      h[Footer]
    end.body
  end.html
end
