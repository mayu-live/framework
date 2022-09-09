def self.get_initial_state(**props)
  { count: 0 }
end

def mount
  loop do
    sleep 1

    update { |state| { count: state[:count].succ } }
  end
end

def render
  h.div do
    h.h1 "Pokemon"
    h.pre state.inspect
  end
end
