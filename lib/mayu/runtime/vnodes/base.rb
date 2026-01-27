# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "securerandom"
require "async"
require "async/queue"

module Mayu
  module Runtime
    module VNodes
      class Base
        def initialize(descriptor, parent:)
          @descriptor = descriptor
          @parent = parent
          @id = SecureRandom.alphanumeric
          @state = :unmounted
        end

        def mounted? = @state in :mounted
        def removed? = @state in :removed

        def start(parent_task: @parent&.task || Async::Task.current)
        end

        def stop
          @task&.stop
        end

        def task = @task || parent.task

        def render_html(out)
        end
      end
    end
  end
end
