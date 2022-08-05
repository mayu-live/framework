initial_state do
  {
    result: nil,
    page: 0,
    per_page: 20,
  }
end

mount do
  result = fetch("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0").json(symbolize_names: true)
  update(result:)
rescue => e
  update(error: e.message)
end

handler :next_page do |e|
  update do |state|
    per_page = state[:per_page]
    total_pages = (state[:result][:results].length / per_page).floor
    page = [state[:page] + 1, total_pages].min
    { page: }
  end
end

handler :prev_page do |e|
  update do |state|
    page = [state[:page] - 1, 0].max
    { page: }
  end
end

handler :set_per_page do |e|
  update(
    per_page: e["value"].to_i,
    page: 0,
  )
end

render do
  pokemons =
    case state[:result]
    in nil
      h.p {
        h "Loading pokémon from "
        h.a "PokéAPI", href: "https://pokeapi.co"
        h "..."
      }
    in results:
      per_page = state[:per_page]
      total_pages = (results.length / per_page).floor
      results_on_this_page = results.slice(state[:page] * per_page, per_page) || []

      h.div {
        h.div(class: styles.pagination) {
          h.div {
            h "Per page: "
            h.select(on_change: handler(:set_per_page), value: state[:per_page]) {
              [20, 40, 80].each do |value|
                h.option value, value:
              end
            }
          }

          h.div {
            h.button "Previous page", on_click: handler(:prev_page)
            h.span "Page #{state[:page] + 1} of #{total_pages + 1}"
            h.button "Next page", on_click: handler(:next_page)
          }
        }

        h.div {
          results_on_this_page.each do |result|
            id = result[:url].scan(/\/(\d+)\//).flatten.last.to_i

            h.li(key: result[:url]) {
              h.a result[:name].capitalize, href: "/pokemon/#{id}"
            }
          end
        }
      }
    end

  h.div {
    h.h1 "Pokémon"

    if state in error:
      h.p error
    end

    h pokemons
  }
end
