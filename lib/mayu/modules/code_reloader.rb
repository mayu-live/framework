# typed: strict

require 'filewatcher'

module Mayu
  module Modules
    class CodeReloader
      extend T::Sig

      sig{returns(Async::Queue)}
      attr_reader :notification

      sig{params(system: System).void}
      def initialize(system)
        @system = system
        @notification = T.let(Async::Queue.new, Async::Queue)
      end

      sig {params(block: T.proc.void).void}
      def on_update(&block)
        last_value = $MAYU_LAST_UPDATE

        loop do
          new_value = $MAYU_LAST_UPDATE

          unless last_value == new_value
            last_value = new_value
            yield
          end

          sleep 0.1
        end
      end

      sig {params(task: Async::Task).void}
      def start(task: Async::Task.current)
        task.async do |task|
          Filewatcher.new(@system.root, every: true).watch do |file|
            puts "\e[36mFile change detected: #{file}\e[0m"
            if File.exist?(file)
              if @system.reload_module(file)
                $MAYU_LAST_UPDATE = Time.now
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
