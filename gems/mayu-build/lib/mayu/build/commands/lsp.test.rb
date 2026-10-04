#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "stringio"
require "tmpdir"
require "fileutils"

require_relative "../../build"
require_relative "../cli"

class Mayu::Build::Commands::LspTest < Minitest::Test
  # Drives the command over pipes the way an editor would.
  class Client
    def initialize(server_input, server_output, status)
      @input = server_input
      @output = server_output
      @status = status
      @next_id = 0
    end

    def request(method, params = {})
      id = (@next_id += 1)
      send(id:, method:, params:)
      read
    end

    def notify(method, params = {})
      send(method:, params:)
    end

    def read
      @output.wait_readable(10) or raise "timed out waiting for the server"
      header = @output.gets("\r\n\r\n")

      unless header
        # Re-raise whatever stopped the server; otherwise explain the silence.
        @status.value
        raise "server closed its output"
      end

      unless header.start_with?("Content-Length:")
        raise "unexpected output before the protocol header: #{header.inspect}"
      end

      length = header[/Content-Length: (\d+)/i, 1].to_i
      JSON.parse(@output.read(length), symbolize_names: true)
    end

    def exit_status
      @status.value
    end

    private

    def send(message)
      body = JSON.generate(message.merge(jsonrpc: "2.0"))
      @input.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
      @input.flush
    end
  end

  def test_reports_missing_mayu_toml
    Dir.mktmpdir("mayu-lsp") do |dir|
      output = StringIO.new

      status = Dir.chdir(dir) { Mayu::Build::Commands::Lsp.new([], output:).call }

      assert_equal(1, status)
      assert_match(/Could not find mayu\.toml/, output.string)
    end
  end

  def test_publishes_diagnostics_for_app_haml
    with_app do |root, client|
      result = client.request("initialize", capabilities: {}).fetch(:result)
      assert_equal("klenod", result.dig(:serverInfo, :name))

      uri = "file://#{File.join(root, "app", "root.haml")}"
      source = <<~HAML
        :ruby
          Missing = import("/components/Missing")
        %Missing
      HAML
      client.notify(
        "textDocument/didOpen",
        textDocument: {uri:, languageId: "haml", version: 1, text: source}
      )
      published = client.read

      assert_equal("textDocument/publishDiagnostics", published[:method])
      assert_equal(uri, published.dig(:params, :uri))
      diagnostics = published.dig(:params, :diagnostics)
      refute_empty(diagnostics)
      assert_match(/Missing/, diagnostics.first[:message])

      assert_nil(client.request("shutdown").fetch(:result))
      client.notify("exit")
      assert_equal(0, client.exit_status)
    end
  end

  def test_application_does_not_print_the_banner
    build = lambda do |input, output, _root|
      with_stdin(input) { Mayu::Build::CLI::Application.new(["lsp"], output:) }
    end

    with_app(build:) do |_root, client|
      response = client.request("initialize", capabilities: {})

      assert_equal(1, response[:id])
      client.notify("exit")
      assert_equal(1, client.exit_status)
    end
  end

  def test_locates_the_app_from_a_directory_argument
    build = lambda do |input, output, root|
      Mayu::Build::Commands::Lsp.new([File.join(root, "app")], input:, output:)
    end

    with_app(build:, run_from: Dir.tmpdir) do |root, client|
      client.request("initialize", capabilities: {})

      uri = "file://#{File.join(root, "app", "root.haml")}"
      client.notify(
        "textDocument/didOpen",
        textDocument: {uri:, languageId: "haml", version: 1, text: "%p Hello\n"}
      )
      published = client.read

      assert_equal("textDocument/publishDiagnostics", published[:method])
      assert_empty(published.dig(:params, :diagnostics))
      client.notify("exit")
    end
  end

  private

  def with_stdin(io)
    previous = $stdin
    $stdin = io
    yield
  ensure
    $stdin = previous
  end

  def with_app(
    build: ->(input, output, _root) { Mayu::Build::Commands::Lsp.new([], input:, output:) },
    run_from: nil
  )
    Dir.mktmpdir("mayu-lsp") do |tmpdir|
      # Klenod resolves the source directory to its real path, and the server
      # only handles documents below it, so the URIs must use the real path too
      # (macOS puts temp dirs behind a /var -> /private/var symlink).
      root = File.realpath(tmpdir)
      File.write(File.join(root, "mayu.toml"), "[development]\n")
      FileUtils.mkdir_p(File.join(root, "app", "pages"))
      File.write(File.join(root, "app", "root.haml"), "%p Hello\n")

      client_to_server_reader, client_to_server_writer = IO.pipe
      server_to_client_reader, server_to_client_writer = IO.pipe
      command = build.call(client_to_server_reader, server_to_client_writer, root)

      # By default start from a subdirectory to exercise the upward search for
      # mayu.toml. Closing the writer when the command stops unblocks a waiting
      # client.
      cwd = run_from || File.join(root, "app", "pages")
      status =
        Thread.new do
          Dir.chdir(cwd) { command.call }
        ensure
          server_to_client_writer.close unless server_to_client_writer.closed?
        end
      client = Client.new(client_to_server_writer, server_to_client_reader, status)

      yield root, client
    ensure
      client_to_server_writer.close unless client_to_server_writer.closed?
      status&.join(10)
      [client_to_server_reader, server_to_client_reader, server_to_client_writer].each do |io|
        io.close unless io.closed?
      end
    end
  end
end
