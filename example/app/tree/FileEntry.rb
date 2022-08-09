def icon
  case File.extname(props[:path])
  when ".rb"
    "🔺"
  when ".mayu"
    "🐍"
  else
    "📄"
  end
end

# stree-ignore
render do
  list_style_type = "'\\%s'" % icon.codepoints.first.to_s(16)

  h.li class: styles.file, style: { list_style_type: } do
    h << File.basename(props[:path])
  end.li
end
