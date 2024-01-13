def format_component(c)
  format("%d%%", (c.to_i(16) / 255.0 * 100).round)
end

File.write(
  "root.css",
  File
    .read("root.css")
    .gsub(/#([[:xdigit:]]{8})/) do
      $~[1].scan(/../) => [r, g, b, a]
      [
        [r, g, b].map { format_component(_1) }.join(" "),
        format_component(a)
      ].join(" / ")
    end
    .gsub(/#([[:xdigit:]]{6})/) do
      $~[1].scan(/../).map { format_component(_1) }.join(" ")
    end
    .gsub(/#([[:xdigit:]]{3})\b/) do
      $~[1].scan(/./).map { format_component(_1 * 2) }.join(" ")
    end
    .gsub(/#([[:xdigit:]]{4})\b/) do
      $~[1].scan(/./) => [r, g, b, a]
      [
        [r, g, b].map { format_component(_1 * 2) }.join(" "),
        format_component(a * 2)
      ].join(" / ")
    end
)
