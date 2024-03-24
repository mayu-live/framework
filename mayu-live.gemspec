# frozen_string_literal: true

require_relative "lib/mayu/version"

Gem::Specification.new do |spec|
  spec.name = "mayu-live"
  spec.version = Mayu::VERSION
  spec.authors = ["Andreas Alin"]
  spec.email = ["andreas.alin@gmail.com"]

  spec.summary = "Server side VDOM framework"

  spec.description = <<~EOF
    Mayu Live is a live updating server side VirtualDOM framework for Ruby,
    inspired by modern frontend tools that exist in the JavaScript ecosystem.
  EOF

  spec.homepage = "https://mayu.live/"
  spec.license = "AGPL-3.0"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mayu-live/framework"
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files =
    Dir.chdir(__dir__) do
      [
        "mayu-live.gemspec",
        "COPYING",
        "README.md",
        *Dir.glob("exe/**/*"),
        *Dir.glob("lib/**/*")
          .grep_v("/node_modules")
          .grep_v("/mayu/client/")
          .grep_v("/__test__")
          .grep_v(%r{\.test\.rb\z}),
        *Dir.glob("lib/mayu/client/dist/**/*"),
      ]
    end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Core
  spec.add_dependency "async", "~> 2.8"
  spec.add_dependency "async-http", "~> 0.62.0"
  spec.add_dependency "async-io", "~> 1.41"
  spec.add_dependency "base64", "~> 0.2.0"
  spec.add_dependency "toml", "~> 0.3.0"

  # Server
  spec.add_dependency "brotli", "~> 0.4.0"
  spec.add_dependency "msgpack", "~> 1.7"
  spec.add_dependency "rack", ">= 3.0.4.1", "< 3.0.10.0"
  spec.add_dependency "rbnacl", "~> 7.1"

  # Development
  spec.add_dependency "filewatcher", "~> 2.1"
  spec.add_dependency "localhost", "~> 1.1"
  spec.add_dependency "minitest", "~> 5.21"
  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "pry", "~> 0.14.2"
  spec.add_dependency "rouge", "~> 4.2"

  # Modules
  spec.add_dependency "image_size", "~> 3.4"
  spec.add_dependency "mayu-css", "~> 0.1.2"
  spec.add_dependency "mime-types", "~> 3.5"
  spec.add_dependency "rake", "~> 13.1"
  spec.add_dependency "syntax_tree", "~> 6.2"
  spec.add_dependency "syntax_tree-haml", "~> 4.0"
  spec.add_dependency "syntax_tree-xml", "~> 0.1.0"
  spec.add_dependency "tsort", "~> 0.2.0"
end
