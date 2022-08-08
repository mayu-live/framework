render do
  h.div do
    h.label props[:label], for: props[:name]
    h.br
    h.input id: props[:name],
      name: props[:name],
      type: props[:type],
      on_input: props[:on_input],
      autocomplete: "off"
  end.div
end
