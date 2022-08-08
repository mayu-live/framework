Pagination = import('./Pagination')

initial_state do |props|
  {
    result: nil,
    error: nil,
    page: 0,
    per_page: 20,
  }
end

mount do
  sleep 1
  res = fetch("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0")
  result = res.json(symbolize_names: true)
  update(result:)
rescue => e
  update(error: e.message)
end

handler :next_page do |e|
  update do |state|
    per_page = state[:per_page]
    total_pages = (state[:result][:results].length / per_page).floor
    page = [state[:page].succ, total_pages].min
    { page: }
  end
end

handler :prev_page do |e|
  update do |state|
    page = [state[:page].pred, 0].max
    { page: }
  end
end

handler :set_per_page do |e|
  update(
    page: 0,
    per_page: e["value"].to_i,
  )
end

render do
  state => result:

  unless result
    next (
      h.div do
        h.p do
          h << "Loading Pokémon from "
          h.a "PokéAPI", href: "https://pokeapi.co/"
        end.p
        h.p "This actually loads faster but 1 second is added for the async effect"

        if state[:error]
          h.p state[:error]
        end
      end.div
    )
  end

  result => results:

  per_page = state[:per_page]
  total_pages = (results.length / per_page).floor
  results_on_this_page = results.slice(state[:page] * per_page, per_page) || []

  paginator = h[Pagination,
    on_change_per_page: handler(:set_per_page),
    on_click_prev: handler(:prev_page),
    on_click_next: handler(:next_page),
    page: state[:page],
    total_pages: total_pages
  ]

  h.div do
    h.h1 "Pokémon"

    h << paginator

    h.ul do
      results_on_this_page.map do |result|
        h.li key: result[:url] do
          id = result[:url][/\/(\d+)\/$/, 1].to_i
          h.a result[:name].capitalize, href: "/pokemon/#{id}"
        end.li
      end
    end.ul

    h << paginator

    h.details style: { margin: "2em 0" } do
      h.summary "Show source"

      h.pre style: { background: "#f0f0f0", padding: "1em" } do
        h << CGI.escape_html(source)
      end.pre
    end.details
  end.div
end
