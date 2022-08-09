require "matrix"

initial_state do |props|
  {
    x: 0.5,
    y: 0.5,
    direction: 0.3,
    speed: 0.1,
    player_x: 0.0,
    bricks: 10.times.map { 10.times.map { 1.0 } }
  }
end

# http://bocilmania.com/2018/04/21/how-to-get-reflection-vector/
def reflect(i, n)
  dn = 2.0 * i.dot(n)
  i - n * dn
end

def reflect_angle(a, n)
  i = Vector[Math.cos(a), Math.sin(a)].normalize
  r = reflect(i, n)
  Math.atan2(r[1], r[0])
end

mount do
  loop do
    update do |state|
      state => { x:, y:, direction:, speed:, bricks: }

      if x > 1.0
        direction = reflect_angle(direction, Vector[-1, 0])
      elsif x < -1.0
        direction = reflect_angle(direction, Vector[1, 0])
      end

      lol = false

      if y > 1.0
        direction = reflect_angle(direction, Vector[0, 1])
        lol = true
      elsif y < -1.0
        direction = reflect_angle(direction, Vector[0, -1])
        lol = true
      end

      sx = Math.cos(direction)
      sy = Math.sin(direction)

      nx = x + sx * speed
      ny = y + sy * speed

      row_index = ((ny / 2.0 + 0.5) / 0.3).to_i * bricks.length

      if row = bricks[row_index]
        brick_index = (nx / 2.0 + 0.5) * row.length

        if brick = row[brick_index]
          direction = reflect_angle(direction, Vector[0, -1]) if brick > 0.0

          bricks[row_index][brick_index] -= 0.2
        end
      end

      { x: nx, y: ny, direction:, speed:, lol:, bricks: }
    end
    sleep 0.1
  end
  catch => e
  p e
end

def clamp(x, min, max)
  case
  when x > max
    max
  when x < min
    min
  else
    x
  end
end

handler(:move) { |e| update(player_x: clamp(e["value"].to_f, -1.0, 1.0)) }

# stree-ignore
render do
  state => {x:, y:, player_x:, bricks:}

  left = format("%.3f%%", (x / 2.0 + 0.5) * 100)
  top = format("%.3f%%", (y / 2.0 + 0.5) * 100)
  left2 = format("%.3f%%", (player_x / 2.0 + 0.5) * 100)
  player_width = "20%"

  h.div do
    h.p "I thought it would be cool to make a break out game. Work in progress!"
    h.div class: styles.game do
      h.div class: styles.bricks do
        bricks.each_with_index do |row, i|
          row.each_with_index do |brick, j|
            h.div class: styles.brick,
              style: {
                top: "#{(i * 2 + 1) / bricks.length.to_f / 2 * 30}%",
                left: "#{(j * 2 + 1) / row.length.to_f / 2 * 100}%",
                opacity: brick
              },
              key: "#{i}.#{j}"
          end
        end
      end.div
      h.div class: styles.ball, style: { top:, left: }
      h.div class: styles.player, style: { top: "95%", left: left2, width: player_width }
    end.div

    h.input class: styles.controller,
      type: "range",
      min: -1.0,
      max: 1.0,
      step: 0.01,
      initial_value: player_x,
      on_input: handler(:move)

    if state[:lol]
      h << "LOL"
    else
      h << ":("
    end
  end.div
end
