# typed: true

PAGE_FILENAME = "page.mayu"
LAYOUT_FILENAME = "layout.mayu"
NOT_FOUND_FILENAME = "404.mayu"

def path_to_regexp(path)
  parts = path.split('/').map do |part|
    if part.match(/\A\[(?<var>\w+)\]\Z/)
      var = Regexp.escape($~[:var])
      "(?<#{var}>[^/]+)"
    else
      Regexp.escape(part).to_s
    end
  end

  Regexp.new('\A' + parts.join('\/') + '\Z')
end

def build_routes(dir, routes: [], layouts:  [], path: [], level: 0)
  return unless File.directory?(dir)

  dirname = File.basename(dir)
  entries = Dir.entries(dir) - %w(. ..)

  path += level.zero? ? [""] : [dirname]

  if layout = entries.delete(LAYOUT_FILENAME)
    layouts += [File.join(dir, layout)]
  end

  if entries.delete(PAGE_FILENAME)
    routes.push({
      path: path.join('/'),
      regexp: path_to_regexp(path.join('/')),
      layouts:,
      template: File.join(dir, PAGE_FILENAME)
    })
  end

  not_found = entries.delete(NOT_FOUND_FILENAME)

  entries.each do |entry|
    build_routes(File.join(dir, entry), routes:, layouts:, path:, level: level.succ)
  end

  if not_found
    routes.push({
      path: path.join('/'),
      regexp: path_to_regexp(path.join('/')),
      layouts:,
      template: File.join(dir, NOT_FOUND_FILENAME)
    })
  end

  routes
end

# example/pages
# ├── FeatureList.css
# ├── FeatureList.mayu
# ├── about
# │   └── page.mayu
# ├── items
# │   ├── [id]
# │   │   └── page.mayu
# │   ├── layout.mayu
# │   └── page.mayu
# ├── layout.css
# ├── layout.mayu
# └── page.mayu

def match_route(routes, request_path)
  routes.each do |route|
    match = route[:regexp].match(request_path)
    next unless match

    return route.merge(params: match.named_captures)
  end

  raise "404"
end

PAGES_ROOT = File.join(File.dirname(__FILE__), "example", "pages")

routes = build_routes(PAGES_ROOT)

p match_route(routes, "/items/123")
