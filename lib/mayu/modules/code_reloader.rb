# typed: strict

require "filewatcher"

module Mayu
  module Modules
    class CodeReloader
      # The global variable in here is an ugly hack.
      # Couldn't get a way to communicate updates to
      # the renderer from here because I got errors
      # about transfering fibers across threads or
      # something. Tricky to fix. This should work,
      # but it's not very nice. At least it's
      # hidden in this abstraction and not exposed.
      extend T::Sig

      sig { params(system: System).void }
      def initialize(system)
        @system = system
      end

      sig { params(block: T.proc.void).void }
      def on_update(&block)
        last_value = $mayu_code_reloader_last_update

        loop do
          new_value = $mayu_code_reloader_last_update

          unless last_value == new_value
            last_value = new_value
            yield
          end

          sleep 0.1
        end
      end

      sig { params(task: Async::Task).void }
      def start(task: Async::Task.current)
        task.async do |task|
          Filewatcher
            .new(
              %w[app components store].map { File.join(@system.root, _1) },
              every: true
            )
            .watch do |file|
              puts "\e[36mFile change detected: #{file} #{@system.root}\e[0m"
              if File.exist?(file)
                if @system.reload_module(file)
                  $mayu_code_reloader_last_update = Time.now
                end
              else
                @system.remove_module(file)
              end
            end
        end
      end
    end
  end
end
