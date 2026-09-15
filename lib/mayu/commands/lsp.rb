# frozen_string_literal: true

require "samovar"

module Mayu
  module Commands
    # Starts the Klenod language server with Mayu's build context, so editors
    # get the same diagnostics as a build for the app's Haml modules. The
    # protocol runs over stdin/stdout, so nothing else may print to stdout.
    class Lsp < Samovar::Command
      self.description = "Start a language server for editors."

      one :dir,
        "The Mayu app directory, or any directory inside it. Editors that " \
        "start the server elsewhere pass this to locate mayu.toml.",
        default: "."

      def initialize(*, input: $stdin, **)
        super(*, **)
        @input = input
      end

      def call
        require_relative "../configuration"
        require_relative "../build"
        require "klenod/lsp"

        start_dir = File.expand_path(dir)
        path = Configuration.find("mayu.toml", start_dir)

        unless path
          output.puts "Could not find mayu.toml in #{start_dir}"
          return 1
        end

        root = File.dirname(path)

        Dir.chdir(root) do
          context =
            Mayu::Build::Configuration.new(root:, mode: :development).context(analysis: true)
          ::Klenod::LSP::Server.new(context:, input: @input, output:).start
        end
      end
    end
  end
end
