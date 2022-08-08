FileEntry = import("./FileEntry")
DirectoryListing = self

initial_state do |props|
  { path: [], open: props[:initial_open] }
end

handler :toggle_open do |_|
  update { |state| { open: !state[:open] } }
end

render do
  name = File.basename(props[:path])

  entries =
    Dir.entries(props[:path]).-(%w(. ..))
      .grep_v(/node_modules|sorbet|vendor/)
      .sort

  class_name =
    if entries.empty?
      styles.emptyDirectory
    else
      styles.directory
    end

  icon = state[:open] ? "📂" : "📁"
  list_style_type = "'\\%s'" % icon.codepoints.first.to_s(16)

  h.li style: { list_style_type: } do
    h.span class: class_name, on_click: handler(:toggle_open) do
      h << name
    end

    if state[:open]
      h.ul do
        entries.each do |filename|
          path = File.join(props[:path], filename)
          h[
            File.directory?(path) ? DirectoryListing : FileEntry,
            key: filename,
            path: path
          ]
        end
      end.ul
    end
  end.li
end
