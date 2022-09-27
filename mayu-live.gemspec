# frozen_string_literal: true

require_relative "lib/mayu/version"

Gem::Specification.new do |spec|
  spec.name = "mayu-live"
  spec.version = Mayu::VERSION
  spec.authors = ["Andreas Alin"]
  spec.email = ["andreas.alin@gmail.com"]

  spec.summary = "Server side VDOM library"
  spec.homepage = "https://github.com/mayu-live"
  spec.license = "AGPL-3.0"
  spec.required_ruby_version = ">= 3.1.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mayu-live/framework"
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(__dir__) do
      [
        "mayu-live.gemspec",
        "COPYING",
        "README.md",
        *Dir.glob("exe/**/*"),
        *Dir.glob("lib/**/*").grep_v("/node_modules").grep_v("/mayu/client/src")
      ]
    end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "async", "~> 2.0.3"
  spec.add_dependency "async-container", "~> 0.16.12"
  spec.add_dependency "async-http", "~> 0.59.1"
  spec.add_dependency "brotli", "~> 0.4.0"
  spec.add_dependency "crass", "~> 1.0.6"
  spec.add_dependency "image_size", "~> 3.1.0"
  spec.add_dependency "listen", "~> 3.7.1"
  spec.add_dependency "localhost", "~> 1.1.9"
  spec.add_dependency "mime-types", "~> 3.4.1"
  spec.add_dependency "msgpack", "~> 1.5.5"
  spec.add_dependency "nanoid", "~> 2.0.0"
  spec.add_dependency "prometheus-client", "~> 4.0.0"
  spec.add_dependency "protocol-http", "~> 0.23.12"
  spec.add_dependency "pry", "~> 0.14.0"
  spec.add_dependency "rack", "~> 3.0.0"
  spec.add_dependency "rake", "~> 13.0.6"
  spec.add_dependency "rux", "~> 1.0.3"
  spec.add_dependency "sorbet-runtime", "~> 0.5.10148"
  spec.add_dependency "terminal-table", "~> 3.0.1"
  spec.add_dependency "toml-rb", "~> 2.2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end