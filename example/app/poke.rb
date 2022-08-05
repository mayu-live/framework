require "async"
require "async/http/internet"

Async do
  internet = Async::HTTP::Internet.new
  response = internet.get("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0")
  data = response.read
JSON.parse(data)
end
