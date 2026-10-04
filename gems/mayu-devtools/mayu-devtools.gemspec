# frozen_string_literal: true

require_relative "../mayu-live/lib/mayu/version"

Gem::Specification.new do |spec|
  spec.name = "mayu-devtools"
  spec.version = Mayu::VERSION
  spec.authors = ["Andrés Alin"]
  spec.email = ["andreas.alin@gmail.com"]

  spec.summary = "Browser devtools support for Mayu Live"

  spec.description = <<~EOF
    Answers queries from the Mayu browser devtools extension, such as the
    component tree of a session. The development server installs it.
  EOF

  spec.homepage = "https://mayu.live/"
  spec.license = "MPL-2.0"
  spec.required_ruby_version = ">= 4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mayu-live/framework/tree/main/gems/mayu-devtools"

  spec.files =
    Dir.chdir(__dir__) do
      [
        "mayu-devtools.gemspec",
        "COPYING",
        *Dir
          .glob("lib/**/*")
          .grep_v(%r{/__test__/})
          .grep_v(/\.test\.rb\z/)
      ]
    end
  spec.require_paths = ["lib"]

  spec.add_dependency "mayu-live", "= #{Mayu::VERSION}"
end
