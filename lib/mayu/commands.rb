# frozen_string_literal: true

module Mayu
  module Commands
    def self.call(argv)
      case argv
      in ["dev", *rest]
        require_relative "commands/dev"
        Dev.call(*rest)
      in ["transform", *rest]
        require_relative "commands/transform"
        Transform.call(*rest)
      end
    end
  end
end
