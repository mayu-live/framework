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
      def run
        Async do |task|
          Filewatcher.new(@system.root, every: true).watch do |file|
            puts file
          end
        end
      end
    end
  end
end
