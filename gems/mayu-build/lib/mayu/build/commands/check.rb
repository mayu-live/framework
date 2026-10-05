# frozen_string_literal: true

require "samovar"

module Mayu
  module Build
    module Commands
      # Reports the language server's diagnostics for every Ruby, Haml, and
      # CSS file in the app, like a linter. Exits with status 1 when there are
      # any.
      class Check < Samovar::Command
        self.description = "Report editor diagnostics for every source file."

        many :paths, "Files or directories to check. Defaults to the whole app."

        def call
          require "mayu/configuration"
          require_relative "../../build"
          require "klenod/lsp"

          start_dir = Dir.pwd
          path = Mayu::Configuration.find("mayu.toml", start_dir)

          unless path
            output.puts "Could not find mayu.toml in #{start_dir}"
            return 1
          end

          paths = Array(@paths)
          missing = paths.reject { File.exist?(it) }
          unless missing.empty?
            missing.each { output.puts "No such file or directory: #{it}" }
            return 1
          end
          # Klenod's source directory is a real path, so selections must be too.
          paths = paths.map { File.realpath(it) }

          Dir.chdir(File.dirname(path)) do
            configuration = Mayu::Build::Configuration.new(root: Dir.pwd, mode: :development)
            context = configuration.context(analysis: true)
            check = ::Klenod::LSP::Check.new(context:, entrypoints: configuration.bundle_entrypoints)
            ::Klenod::LSP::Check.report(check.call(paths), output:, root: start_dir).zero? ? 0 : 1
          end
        end
      end
    end
  end
end
