# typed: true

def render
  h.div do
    h.h2 "Pokemon"
    h << props[:children].compact.first
  end
end
