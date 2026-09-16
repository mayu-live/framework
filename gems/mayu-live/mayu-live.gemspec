# frozen_string_literal: true

require_relative "lib/mayu/version"

Gem::Specification.new do |spec|
  spec.name = "mayu-live"
  spec.version = Mayu::VERSION
  spec.authors = ["Andrés Alin"]
  spec.email = ["andreas.alin@gmail.com"]

  spec.summary = "Server side VDOM framework"

  spec.description = <<~EOF
    Mayu Live is a live updating server side VirtualDOM framework for Ruby,
    inspired by modern frontend tools that exist in the JavaScript ecosystem.

    This gem runs a built Mayu app. Install mayu-build as well to develop one.
  EOF

  spec.homepage = "https://mayu.live/"
  spec.license = "MPL-2.0"
  spec.required_ruby_version = ">= 4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mayu-live/framework/tree/main/gems/mayu-live"

  spec.files =
    Dir.chdir(__dir__) do
      [
        "mayu-live.gemspec",
        "COPYING",
        *Dir.glob("exe/**/*"),
        *Dir
          .glob("lib/**/*")
          .grep_v(%r{/node_modules/})
          .grep_v(%r{/mayu/client/})
          .grep_v(%r{/__test__/})
          .grep_v(/\.test\.rb\z/),
        *Dir.glob("lib/mayu/client/dist/**/*")
      ]
    end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Klenod platform: only the runtime half. Building an app needs mayu-build.
  spec.add_dependency "klenod-runtime", "= 0.0.16"
  spec.add_dependency "klenod-rack", "= 0.0.16"

  # Server
  spec.add_dependency "async", "~> 2.42"
  spec.add_dependency "async-container", "~> 0.30.0"
  spec.add_dependency "async-signals", "~> 0.6.0"
  spec.add_dependency "async-http", ">= 0.95.1", "< 0.104.0"
  spec.add_dependency "brotli", "~> 0.8"
  spec.add_dependency "mime-types", "~> 3.7"
  spec.add_dependency "msgpack", "~> 1.8"
  spec.add_dependency "prometheus-client", "~> 4.2.4"
  spec.add_dependency "rack", ">= 3.2.4"
  spec.add_dependency "rbnacl", "~> 7.1"

  # Configuration
  spec.add_dependency "base64", "~> 0.3"
  spec.add_dependency "dotenv", "~> 3.2"
  spec.add_dependency "toml", "~> 0.3"
end
