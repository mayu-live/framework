ITEMS = ["server side rendered apps", "very fast", "wow"]

def self.get_initial_state(**props)
  { index: 0 }
end

def mount
  loop do
    sleep 1

    update { |state| { index: state[:index].succ % ITEMS.size } }
  end
end

def render
  h.div class: styles.foo do
    h.ul do
      ITEMS.each_with_index do |item, index|
        if index == state[:index]
          h.li item, key: index, class: styles.active
        else
          h.li item, key: index
        end
      end
    end
    h << "hello"
  end
end
