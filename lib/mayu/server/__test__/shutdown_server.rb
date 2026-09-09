# frozen_string_literal: true

require_relative "../../server"

root = ARGV.fetch(0)
config = Mayu::Configuration::Config.parse(root, {
  "secret_key" => "shutdown-test-secret",
  "server" => {
    "listen" => "http://127.0.0.1:0",
    "shutdown_timeout_seconds" => ENV.fetch("TEST_DRAIN_TIMEOUT", "10"),
    "transfer_timeout_seconds" => 60,
    "session_timeout_seconds" => 60
  },
  "metrics" => {"enabled" => ENV["TEST_METRICS"] == "true", "listen" => "http://127.0.0.1:0"}
})
bundle = File.join(root, "app.mayu-bundle")

if ARGV[1] == "resume"
  environment = Mayu::Environment.load_klenod_with_config(config, bundle)
  state = Mayu::Session::TransferState.decrypt(environment.marshaller, File.binread(ARGV.fetch(2)))
  puts state.resume(environment).render
  exit
end

module DrainDelay
  def stop
    File.write(File.join(@environment.config.root, "draining-#{Process.pid}"), "draining")
    sleep ENV.fetch("TEST_DRAIN_DELAY", "0").to_f
    super
  end
end
Mayu::Server::App.prepend(DrainDelay)

if ENV["TEST_TRANSFER_FAILURE"] == "error"
  Mayu::Session.prepend(Module.new do
    def transfer!
      raise TypeError, "Test serialization failure"
    end
  end)
end

class ShutdownTestController < Mayu::Server::Controller
  class Ready
    def initialize(instance, root)
      @instance, @root = instance, root
    end

    def ready!(**options)
      File.write(File.join(@root, "ready-#{Process.pid}"), "ready")
      @instance.ready!(**options)
    end
  end

  def setup(container)
    port = @bound_endpoint.sockets.first.local_address.ip_port
    File.write(File.join(@config.root, "port"), port.to_s)
    super
  end

  def setup_worker(instance, **options)
    super(Ready.new(instance, @config.root), **options)
  end

  def load_environment(**options)
    File.write(File.join(@config.root, "starting-#{Process.pid}"), "starting")
    sleep ENV.fetch("TEST_STARTUP_DELAY", "0").to_f
    super
  end
end

endpoint = Async::HTTP::Endpoint.parse(config.server.listen, protocol: Async::HTTP::Protocol::HTTP2)
ShutdownTestController.new(config:, mayu_env: :production, endpoint:, bundle_filename: bundle).run
