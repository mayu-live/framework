require_relative "../runtime/h"

module Mayu
  class Session
    module ErrorPage
      H = Runtime::H

      def self.build(message)
        [
          H[:head, H[:title, "Error: #{message}"]],
          H[:body, H[:p, "Error: #{message}"]]
        ]
      end
    end
  end
end
