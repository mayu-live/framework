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
session = Mayu::Session.new(environment:, request_info:)
html = session.render

# Devtools queries must go unanswered in production: only `mayu dev` installs
# an inspector.
engine = session.instance_variable_get(:@engine)
session.send(:handle_event, Mayu::Session::Events.parse(["Inspect", "1", {type: "tree"}, 0]))
commands = []
commands.concat(engine.dequeue_batch.commands) until engine.output_queue.empty?
inspect_result = commands.find { it.is_a?(Mayu::Runtime::Commands::InspectResult) }

puts JSON.generate(
  html:,
  klenod_build_defined: defined?(::Klenod::Build) ? true : false,
  mayu_build_defined: defined?(::Mayu::Build) ? true : false,
  mayu_devtools_defined: defined?(::Mayu::Devtools) ? true : false,
  inspector: !environment.inspector.nil?,
  inspect_result: inspect_result&.deconstruct,
  build_features:
    $LOADED_FEATURES.grep(%r{/klenod/(build|test|lsp|plugin)|/mayu/(build|devtools)|/samovar}).sort
)
