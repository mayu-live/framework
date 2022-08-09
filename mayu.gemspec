# frozen_string_literal: true

require_relative "lib/mayu/version"

Gem::Specification.new do |spec|
  spec.name = "mayu-live"
  spec.version = Mayu::VERSION
  spec.authors = ["Andreas Alin"]
  spec.email = ["andreas.alin@gmail.com"]

  spec.summary = "Server side rendered VDOM library"
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
      `git ls-files -z`.split("\x0")
        .reject do |f|
          (f == __FILE__) ||
            f.match(
              %r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)}
            )
        end
    end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "pry", "~> 0.14.0"
  spec.add_dependency "rake", "~> 13.0.6"
  spec.add_dependency "crass", "~> 1.0.6"
  spec.add_dependency "toml-rb", "~> 2.2.0"
  spec.add_dependency "prometheus-client", "~> 4.0.0"
  spec.add_dependency "falcon", "~> 0.39.2"
  spec.add_dependency "rux", "~> 1.0.3"
  spec.add_dependency "sorbet-runtime", "~> 0.5.10148"
  spec.add_dependency "nanoid", "~> 2.0.0"
  spec.add_dependency "filewatcher", "~> 1.1.1"
  spec.add_dependency "async-http", "~> 0.56.6"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
