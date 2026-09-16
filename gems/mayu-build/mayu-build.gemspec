# frozen_string_literal: true

require_relative "../mayu-live/lib/mayu/version"

Gem::Specification.new do |spec|
  spec.name = "mayu-build"
  spec.version = Mayu::VERSION
  spec.authors = ["Andrés Alin"]
  spec.email = ["andreas.alin@gmail.com"]

  spec.summary = "Development and build tooling for Mayu Live"

  spec.description = <<~EOF
    The development half of Mayu Live: the dev server with hot reloading,
    the production build, tests, routes, and the language server. Install it
    on developer machines next to mayu-live. Production only needs mayu-live.
  EOF

  spec.homepage = "https://mayu.live/"
  spec.license = "AGPL-3.0"
  spec.required_ruby_version = ">= 4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mayu-live/framework/tree/main/gems/mayu-build"

  spec.files =
    Dir.chdir(__dir__) do
      [
        "mayu-build.gemspec",
        "COPYING",
        *Dir
          .glob("lib/**/*")
          .grep_v(%r{/__test__/})
          .grep_v(/\.test\.rb\z/)
      ]
    end
  spec.require_paths = ["lib"]

  spec.add_dependency "mayu-live", "= #{Mayu::VERSION}"

  # Klenod platform: compiling, watching, testing, and editor support.
  spec.add_dependency "klenod-build", "= 0.0.16"
  spec.add_dependency "klenod-test", "= 0.0.16"
  spec.add_dependency "klenod-lsp", "= 0.0.16"
  spec.add_dependency "klenod-plugin-css", "= 0.0.16"
  spec.add_dependency "klenod-plugin-javascript", "= 0.0.16"

  # Self-signed certificates for the development server
  spec.add_dependency "localhost", "~> 1.7"

  # The command line, its output, and scaffolding
  spec.add_dependency "samovar", "~> 2.5"
  spec.add_dependency "reline", "~> 0.6"
  spec.add_dependency "rouge", "~> 4.7"
  spec.add_dependency "terminal-table", "~> 4.0"

  # Mayu::Test, the application test API
  spec.add_dependency "minitest", "~> 6.0"
  spec.add_dependency "oga", "~> 3.4"
end
