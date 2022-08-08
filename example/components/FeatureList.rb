ITEMS = [
  "Component-based, inspired by React",
  "JSX-inspired syntax",
  "100% server side",
  "100% async",
  "CSS-modules",
  "Asset handling (image compression etc)",
  "Hot-reloading",
]

initial_state do |props|
  { active: 0 }
end

mount do
  loop do
    sleep 3

    update do |state|
      { active: state[:active].succ % ITEMS.size }
    end
  end
end

render do
  h.ul do
    ITEMS.map.with_index do |item, i|
      class_name = state[:active] == i ? styles.active : ""
      h.li item, class: class_name
    end
  end.ul
end
