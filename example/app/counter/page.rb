initial_state { |props| { count: 0, running: false } }

handler :add do |x, amount|
  update { |state| { count: state[:count] + amount } }
end

handler :reset do |x|
  update(count: 0)
end

handler :toggle do |x|
  if state[:running]
    update(running: false)
    return
  else
    update(running: true)
  end

  async do
    loop do
      update { |state| { count: state[:count].succ } }
      sleep 0.5
      break unless state[:running]
    end
  end
end

handler :crash do |x|
  sleep 0.5
  raise "Crashed"
end

should_update? { |next_props, next_state| super(next_props, next_state) }

# stree-ignore
render do
  autocount_info =
    if state[:running]
      h.p do
        "Auto-counter is currently running. To stop it, click the button you clicked to start it."
      end.p
    end

  h.div do
    h.h1 "Counter"
    h.p class: styles.count do
      h << "Count: "
      h.span class: styles.value do
        h << state[:count]
      end.span
    end.p

    h.div class: styles.buttons do
      [1, 10, 42, 50].each do |amount|
        h.button class: styles.button, on_click: handler(:add, amount) do
          h << "Add #{amount}"
        end.button
      end
    end.div

    h.hr

    h.div class: styles.buttons do
      h.button class: styles.button, on_click: handler(:toggle) do
        h << (state[:running] ? "Stop autocount" : "Start autocount")
      end

      h.button class: styles.button, on_click: handler(:reset) do
        h << "Reset"
      end
    end.div

    h.div class: styles.buttons do
      h.button "Crash", on_click: handler(:crash)
    end

    h << autocount_info
  end.div
end
