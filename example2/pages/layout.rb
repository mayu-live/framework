# typed: true

def render
  h.html do
    h.head do
      h.meta name: "charset", value: "utf-8"
      h.title "Mayu Live"
    end

    h.body(class: styles.body) do
      h.header(class: styles.header) do
        h.div(class: styles.maxWidth) { h.h1 "Mayu Live", class: styles.title }
      end

      h.nav(class: styles.nav) do
        h.menu(class: "#{styles.menu} #{styles.maxWidth}") do
          h.li { h.a "Start page", href: "/" }
          h.li { h.a "Pokemon", href: "/pokemon" }
        end
      end

      h.main { h.section(class: styles.maxWidth) { h << children.first } }
    end
  end
end
