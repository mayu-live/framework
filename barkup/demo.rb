# typed: strict

require_relative "barkup"

output = Barkup.build do
  h.div do
    h.h1 "Page title"

    h.table do
      h.tbody do
        h.tr do
          h.td "Item 1"
          h.td "User 1"
        end.tr

        h.tr do
          h.td "Item 2"
          h.td "User 1"
        end.tr

        h.tr do
          h.td "Item 3"
          h.td "User 2"
        end.tr
      end.tbody
    end.table

    h.div do
      h "Hello "
      h.span "world", style: "font-weight: bold;"
    end.div
  end.div
end

puts output
