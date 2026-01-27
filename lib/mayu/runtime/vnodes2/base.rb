# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "securerandom"

module Mayu
  module Runtime
    module VNodes2
      class Base
        attr_reader :id, :descriptor, :parent, :engine

        def initialize(descriptor, parent:, engine:)
          @descriptor = descriptor
          @parent = parent
          @engine = engine
          @id = SecureRandom.alphanumeric
          @task = nil
          @is_new = true
          @is_inserted = false
          @is_removed = false
        end

        def task
          @task || @parent&.task
        end

        def closest(type)
          if type === self
            self
          else
            @parent&.closest(type)
          end
        end

        def start
        end

        def stop
        end

        def update(_patcher)
        end

        def write_html(_out)
        end

        def inserted?
          @is_inserted
        end

        def removed?
          @is_removed
        end

        def new?
          @is_new
        end

        def mark_inserted
          @is_new = false
          @is_inserted = true
        end

        def mark_removed
          @is_removed = true
          @is_inserted = false
        end
      end
    end
  end
end
