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
  end
end

initial_state do |props|
  { result: nil, page: 0, per_page: 20 }
end

mount do
  sleep 1
  internet = Async::HTTP::Internet.new
  response = internet.get("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0")
  update(result: JSON.parse(response.read, symbolize_names: true))
rescue => e
  update(error: e.message)
end

handler :next_page do |e|
  update do |state|
    per_page = state[:per_page]
    total_pages = (state[:result][:results].length / per_page).floor
    { page: [state[:page].succ, total_pages].min }
  end
end

handler :prev_page do |e|
  update { |state| { page: [state[:page].pred, 0].max } }
end

handler :set_per_page do |e|
  update(per_page: e["value"].to_i, page: 0)
end

render do
  pokemons =
    case state[:result]
    in nil
      h.p do
        h "Loading pokémon from "
        h.a "PokéAPI", href: "https://pokeapi.co"
        h "..."
      end
    in results:
      per_page = state[:per_page]
      total_pages = (results.length / per_page).floor
      results_on_this_page = results.slice(state[:page] * per_page, per_page) || []

      h.div do
        h.div(class: styles.pagination) do
          h.div do
            h "Per page: "
            h.select on_change: handler(:set_per_page), value: state[:per_page] do
              [20, 40, 80].each do |value|
                h.option value, value:
              end
            end
          end

          h.div do
            h.button "Previous page", on_click: handler(:prev_page)
            h.span "Page #{state[:page] + 1} of #{total_pages + 1}"
            h.button "Next page", on_click: handler(:next_page)
          end
        end

        h.div do
          results_on_this_page.each do |result|
            id = result[:url].scan(/\/(\d+)\//).flatten.last.to_i

            h.li key: result[:url] do
              h.a result[:name].capitalize, href: "/pokemon/#{id}"
            end
          end
        end
      end

    h.div do
      h.h1 "Pokémon"

      if state in error:
        h.p error
      end

      h pokemons
    end
  end
end
