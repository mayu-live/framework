module Mayu
  module Commands
    def self.call(argv)
      case argv
      in ["dev", *rest]
        require_relative "commands/dev"
        Dev.call(*rest)
      end
    end
  end
end
