initial_state do |props|
  { count: 0, length: 5 }
end

should_update? do |next_props, next_state|
  true
end

handler :rerender do |event|
  update do |state|
    { count: state[:count] + 1 }
  end
end

handler :update_length do |event|
  update do |state|
    { length: event["value"].to_i }
  end
end

render do
  numbers = state[:length].times.to_a.shuffle

  h.div do
    h.h1 "Random numbers"

    h.button on_click: handler(:rerender) do
      h << "Rerender"
    end.button

    h.p "numbers: #{numbers.inspect}"

    h.input type: "range",
      min: 0,
      max: 20,
      value: state[:value],
      on_input: handler(:update_length)

    h.ul do
      numbers.each do |i|
        h.li key: i, style: { "background-color": "hsl(#{i * 36}deg, 80%, 80%)" } do
          h << i.to_s
        end
      end
    end.ul
  end.div
end

