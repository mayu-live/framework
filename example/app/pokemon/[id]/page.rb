initial_state do |props|
  { result: nil, error: nil }
end

mount do
  res = fetch("https://pokeapi.co/api/v2/pokemon/1/")
  result = res.json(symbolize_names: true)
  update(result:)
rescue => e
  update(error: e.message)
end

render do
  pokemon = state[:result]

  unless pokemon
    return (
      h.p do
        h << "Loading pokemon"
      end.p
    )
  end

  h.div do
    h.h1 pokemon[:name]
    h.img src: pokemon.dig(:sprites, :front_default)
    h.p "This page will show #{pokemon[:name]} until pages can read url parameters."
  end.div
end
