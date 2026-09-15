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

        def checkpoint
          @commands.length
        end

        def rollback(checkpoint)
          @commands.slice!(checkpoint..)
        end
      end

      class NullCommandCollector
        def <<(_command)
        end

        def checkpoint = 0

        def rollback(_checkpoint)
        end
      end
    end
  end
end
