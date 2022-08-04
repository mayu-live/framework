# typed: strict

require 'filewatcher'

module Mayu
  module Modules
    class CodeReloader
      extend T::Sig

      sig{params(system: System).void}
      def initialize(system)
        @system = system
      end

      sig {void}
      def start
        Async do |task|
          Filewatcher.new(@system.root, every: true).watch do |file|
            puts "\e[36mFile change detected: #{file}\e[0m"
            if File.exist?(file)
              @system.reload_module(file)
            else
              @system.remove_module(file)
            end
          end
        end
      end
    end
  end
end
