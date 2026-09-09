#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "async/http/client"
require_relative "../server"

class Mayu::Server::ControllerTest < Minitest::Test
  FIXTURE = File.expand_path("__test__/shutdown_server.rb", __dir__)

  def setup
    @root = Dir.mktmpdir("mayu-shutdown")
    FileUtils.mkdir_p(File.join(@root, "app/pages/pid"))
    File.write(File.join(@root, "app/root.haml"), "%slot\n")
    File.write(File.join(@root, "app/pages/+page.haml"), <<~HAML)
      :ruby
        def initialize
          @count = 0
        end

        def mount
          @count = 41
          rerender!
        end

      %p= "count=\#{@count}"
    HAML
    File.write(File.join(@root, "app/pages/pid/+route.rb"), "def GET(request); [200, {}, Process.pid.to_s]; end")
    Mayu::Klenod::Configuration.new(root: @root, mode: :production).build(output: File.join(@root, "app.mayu-bundle"))
  end

  def teardown
    if @pid
      Process.kill(:KILL, -@pid)
      Process.wait(@pid)
    end
  rescue Errno::ESRCH, Errno::ECHILD
  ensure
    FileUtils.remove_entry(@root)
  end

  def test_two_workers_flush_state_before_parent_exits
    start_server(count: 2, metrics: true)
    workers = worker_pids
    payloads = []
    Async do |task|
      clients = []
      streams = {}
      task.with_timeout(8) do
        until streams.size == 2
          client = new_client
          clients << client
          pid_response = client.get("/pid")
          pid = pid_response.read.to_i
          next if streams.key?(pid)
          page = client.get("/", {"accept" => "text/html"})
          assert_equal(200, page.status)
          session_id = page.headers["x-mayu-session-id"]
          cookie = page.headers["set-cookie"].to_s.split(";").first
          page.read
          stream = client.get("/.mayu/session/#{session_id}", {"cookie" => cookie})
          assert_equal(200, stream.status)
          streams[pid] = stream
        end
        assert_equal(workers.sort, streams.keys.sort)
        Process.kill(:INT, @pid)
        streams.each_value do |response|
          patches = decode(response.read)
          transfer = patches.find { |patch| patch.first == "Transfer" }
          refute_nil(transfer, "Missing transfer: #{patches.map(&:first).inspect}")
          payloads << transfer[1].data
        end
      end
    rescue => error
      flunk("#{error.class}: #{error.message}\n#{logs}")
    ensure
      clients.each(&:close)
    end.wait
    assert_parent_exits(timeout: 4)
    workers.each { |pid| assert_process_gone(pid) }
    payloads.each_with_index do |payload, index|
      path = File.join(@root, "state-#{index}")
      File.binwrite(path, payload)
      html = IO.popen([RbConfig.ruby, "-W0", "-rbundler/setup", FIXTURE, @root, "resume", path], &:read)
      assert($?.success?, logs)
      assert_includes(html, "count=41")
    end
    refute_includes(logs, "Worker drain deadline expired")
    refute_includes(logs, "Killing processes after graceful shutdown failed")
  end

  def test_one_process_group_interrupt_is_graceful
    start_server(delay: 0.2)
    Process.kill(:INT, -@pid)
    assert_parent_exits(timeout: 3)
    assert_includes(logs, "Worker drained")
    refute_includes(logs, "forcing shutdown")
  end

  def test_second_mixed_signal_kills_workers_immediately
    start_server(delay: 60)
    workers = worker_pids
    Process.kill(:INT, @pid)
    wait_until { Dir.glob(File.join(@root, "draining-*")).any? }
    started = monotonic
    Process.kill(:TERM, @pid)
    assert_parent_exits(timeout: 2)
    assert_operator(monotonic - started, :<, 2)
    workers.each { |pid| assert_process_gone(pid) }
    refute_includes(logs, "Worker drained")
  end

  def test_drain_deadline_aborts_unfinished_work
    start_server(delay: 60, timeout: 0.15)
    Process.kill(:TERM, @pid)
    assert_parent_exits(timeout: 2)
    assert_includes(logs, "Worker drain deadline expired")
    refute_includes(logs, "Killing processes after graceful shutdown failed")
  end

  def test_interrupt_during_worker_initialization_is_not_lost
    start_server(startup_delay: 0.2, ready: false)
    wait_until { Dir.glob(File.join(@root, "starting-*")).any? }
    Process.kill(:INT, @pid)
    assert_parent_exits(timeout: 3)
    assert_includes(logs, "Worker drained")
  end

  def test_worker_crashes_restart_but_shutdown_does_not_restart
    start_server
    old_pid = worker_pids.first
    Process.kill(:KILL, old_pid)
    wait_until { worker_pids.size == 2 }
    Process.kill(:TERM, @pid)
    assert_parent_exits(timeout: 3)
    assert_equal(2, worker_pids.size)
    worker_pids.each { |pid| assert_process_gone(pid) }
  end

  def test_drain_rejects_new_requests_and_closes_listeners
    start_server(delay: 0.5, metrics: true)
    Async do |task|
      client = new_client
      task.with_timeout(3) do
        assert_equal(200, client.get("/pid").tap(&:read).status)
        Process.kill(:INT, @pid)
        wait_until { Dir.glob(File.join(@root, "draining-*")).any? }
        response = client.get("/pid")
        assert_equal(503, response.status)
        assert_equal("Server is stopping", response.read)
        port = File.read(File.join(@root, "port")).to_i
        assert_raises(Errno::ECONNREFUSED) { TCPSocket.new("127.0.0.1", port).close }
      end
    ensure
      client&.close
    end.wait
    assert_parent_exits(timeout: 3)
  end

  def test_stalled_http2_output_cannot_hold_worker_past_drain_deadline
    start_server(timeout: 0.2)
    Async do |task|
      client = new_client
      stalled_client = nil
      task.with_timeout(3) do
        page = client.get("/", {"accept" => "text/html"})
        id = page.headers["x-mayu-session-id"]
        cookie = page.headers["set-cookie"].to_s.split(";").first
        page.read
        stalled_client = new_client(window: 0)
        response = stalled_client.get("/.mayu/session/#{id}", {"cookie" => cookie})
        assert_equal(200, response.status)
        Process.kill(:TERM, @pid)
        assert_parent_exits(timeout: 2)
        assert_includes(logs, "Worker drain deadline expired")
        refute_includes(logs, '"flushed":true')
      end
    ensure
      client&.close
      stalled_client&.close
    end.wait
  end

  def test_worker_signal_drains_and_supervisor_replaces_it
    start_server
    worker = worker_pids.first
    Process.kill(:TERM, worker)
    wait_until { worker_pids.size == 2 }
    assert_process_gone(worker)
    assert_includes(logs, "Worker drained")
    Process.kill(:INT, @pid)
    assert_parent_exits(timeout: 3)
  end

  def test_failed_serialization_finishes_the_stream_and_worker
    start_server(transfer_failure: "error")
    Async do |task|
      client = new_client
      task.with_timeout(3) do
        page = client.get("/", {"accept" => "text/html"})
        id = page.headers["x-mayu-session-id"]
        cookie = page.headers["set-cookie"].to_s.split(";").first
        page.read
        response = client.get("/.mayu/session/#{id}", {"cookie" => cookie})
        Process.kill(:INT, @pid)
        patches = decode(response.read)
        assert_equal(["TransferFailed"], patches.last)
      end
    ensure
      client&.close
    end.wait
    assert_parent_exits(timeout: 3)
    refute_includes(logs, "Worker drain deadline expired")
  end

  def test_development_always_uses_one_worker
    controller = Mayu::Server::Controller.allocate
    controller.instance_variable_set(:@mayu_env, :development)
    assert_equal(1, controller.send(:worker_count))
  end

  private

  def start_server(count: 1, delay: 0, timeout: 10, startup_delay: 0, ready: true, metrics: false, transfer_failure: nil)
    @pid = Process.spawn(
      {"ASYNC_CONTAINER_PROCESSOR_COUNT" => count.to_s, "WEB_CONCURRENCY" => "99",
       "TEST_DRAIN_DELAY" => delay.to_s, "TEST_DRAIN_TIMEOUT" => timeout.to_s,
       "TEST_STARTUP_DELAY" => startup_delay.to_s, "TEST_METRICS" => metrics.to_s,
       "TEST_TRANSFER_FAILURE" => transfer_failure,
       "CONSOLE_LEVEL" => "info"},
      RbConfig.ruby, "-W0", "-rbundler/setup", FIXTURE, @root,
      pgroup: true, out: File.join(@root, "server.log"), err: [:child, :out]
    )
    wait_until { worker_pids.size == count } if ready
  end

  def worker_pids
    Dir.glob(File.join(@root, "ready-*")).map { |path| File.basename(path).delete_prefix("ready-").to_i }
  end

  def new_client(window: nil)
    port = File.read(File.join(@root, "port")).to_i
    protocol = Async::HTTP::Protocol::HTTP2
    unless window.nil?
      protocol = protocol.new(settings: protocol::CLIENT_SETTINGS.merge(Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE => window))
    end
    endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:#{port}", protocol:)
    Async::HTTP::Client.new(endpoint, retries: 0)
  end

  def decode(bytes)
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    unpacker = Mayu::Server::EventStream::MsgPackWrapper.new.unpacker
    unpacker.feed(inflater.inflate(bytes))
    assert(inflater.finished?, "Missing compression trailer")
    unpacker.each.to_a.flatten(1)
  ensure
    inflater&.close
  end

  def logs
    File.read(File.join(@root, "server.log"))
  end

  def assert_parent_exits(timeout:)
    status = nil
    wait_until(timeout:) { status = Process.waitpid2(@pid, Process::WNOHANG)&.last }
    group = @pid
    @pid = nil
    assert(status.success?, logs)
    assert_raises(Errno::ESRCH) { Process.kill(0, -group) }
  end

  def assert_process_gone(pid)
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def wait_until(timeout: 8)
    deadline = monotonic + timeout
    until yield
      flunk("Timed out waiting for subprocess:\n#{logs}") if monotonic >= deadline
      sleep 0.01
    end
  end
end
