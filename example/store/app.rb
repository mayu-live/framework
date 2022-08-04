# typed: true

extend T::Sig
extend Mayu::State::ReducerDSL

initial_state(items: [])

actions do
  AddItem = action(:AddItem)
  RemoveItem = action(:RemoveItem)

  LoadItems = async(:LoadItems) do |store|
    puts "Loading items"
    sleep 1
    puts "Loaded items"
    rand(10).succ.times.map { "Loaded item #{_1.succ}" }
  end
end

reducer(AddItem) do |state, payload|
  state[:items].push(payload)
  state
end

reducer(RemoveItem) do |state, payload|
  state[:items].delete(payload)
  state
end

reducer(LoadItems.pending) do |state, payload|
  state[:loading] = true
  state
end

reducer(LoadItems.fulfilled) do |state, payload|
  state[:loading] = false
  state[:items] = payload
  state
end

reducer(LoadItems.rejected) do |state, payload|
  state[:loading] = false
  state
end
