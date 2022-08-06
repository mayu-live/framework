# typed: strict

module Barkup
  class Builder
  end
end
require_relative "barkup"

styles = {
  menu_open: 'menuOpen',
  menu_closed: 'menuClosed',
}

state = {}

out = Barkup.build do
  h.div do
    h.h1 "hejsan"

    menu_class =
      if state[:menu_open]
        styles[:menu_open]
      else
        styles[:menu_closed]
      end

    h.menu(class: menu_class) do
      10.times do |i|
        h.li(key: i) do
          h "Item #{i}"
        end
      end
    end

    h.h1 class: [] do
    end

    h.div(class: ['xx']) do
    end
  end
end

puts out
