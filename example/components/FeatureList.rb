ITEMS = [
  "Component-based, inspired by React",
  "JSX-inspired syntax",
  "100% server side",
  "100% async",
  "CSS-modules",
  "Asset handling (image compression etc)",
  "Hot-reloading"
]

initial_state { |props| { active: 0 } }

mount do
  Console.logger.warn("MOUNT!!!")
  loop do
    sleep 3

    update { |state| { active: state[:active].succ % ITEMS.size } }
  end
end

render do
  h
    .ul do
      ITEMS.map.with_index do |item, i|
        class_name = state[:active] == i ? styles.active : ""
        h.li item, class: class_name
      end
    end
    .ul
end
