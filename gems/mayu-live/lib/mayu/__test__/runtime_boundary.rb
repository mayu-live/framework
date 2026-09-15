# frozen_string_literal: true

# Boots the production code path against a prebuilt bundle, then reports which
# build-side constants and files ended up loaded. Run in a fresh process by
# runtime_boundary.test.rb so nothing from the test process leaks in.

require "json"
require_relative "../cli"
require_relative "../configuration"
require_relative "../server"

root = ARGV.fetch(0)
bundle = ARGV.fetch(1)

config =
  Mayu::Configuration::Config.parse(
    root,
    {
      "secret_key" => "runtime-boundary-secret",
      "server" => {"listen" => "http://127.0.0.1:0"},
      "metrics" => {"enabled" => false, "listen" => "http://127.0.0.1:0"}
    }
  )

environment =
  Mayu::Environment.load_klenod_with_config(config, bundle)
request_info =
  Mayu::Session::RequestInfo.new(path: "/", headers: {}, http2: false)
html = Mayu::Session.new(environment:, request_info:).render

puts JSON.generate(
  html:,
  klenod_build_defined: defined?(::Klenod::Build) ? true : false,
  mayu_build_defined: defined?(::Mayu::Build) ? true : false,
  build_features:
    $LOADED_FEATURES.grep(%r{/klenod/(build|test|lsp|plugin)|/mayu/build|/samovar}).sort
)
