APP_ROOT = File.expand_path(".")
PAGES_ROOT = File.join(APP_ROOT, "app")
COMPONENTS_ROOT = File.join(APP_ROOT, "components")

class ResolveError < StandardError
end

def in_valid_directory?(path)
  path.start_with?(COMPONENTS_ROOT) || path.start_with?(PAGES_ROOT)
end

def resolve_component(path, source_path)
  resolved_path =
    if path.match(%r{\A\.\.?/})
      File.expand_path(path, File.dirname(source_path))
    else
      File.expand_path(path, COMPONENTS_ROOT)
    end

  unless in_valid_directory?(resolved_path)
    raise ResolveError, "Could not resolve #{path} from #{source_path}"
  end

  if File.directory?(resolved_path)
    resolved_path = File.join(resolved_path, File.basename(resolved_path))
  end

  resolved_path = resolved_path.sub(/(\.mayu)?$/, ".mayu")

  return resolved_path if File.exist?(resolved_path)

  raise ResolveError,
        "Could not resolve #{path} from #{source_path} (tried #{resolved_path})"
end

puts resolve_component("Layout/Header", File.join(PAGES_ROOT, "page.mayu"))
puts resolve_component(
       "./Header",
       File.join(COMPONENTS_ROOT, "Layout", "Layout.mayu")
     )
