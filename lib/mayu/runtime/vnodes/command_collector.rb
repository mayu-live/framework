# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class CommandCollector
        attr_reader :commands

        def initialize
          @commands = []
        end

        def <<(command)
          @commands << command
        end
      end

      class NullCommandCollector
        def <<(_command)
        end
      end
    end
  end
end
