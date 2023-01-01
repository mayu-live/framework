# typed: false

module OpenSSL
  class << self
    def fixed_length_secure_compare(a, b)
    end
  end
end

module URI
  class << self
    def for(scheme, *arguments, default: Generic)
    end
  end
end

class RubyVM
  module YJIT
    class << self
      def enabled?
      end
    end
  end
end

class RubyVM
  module MJIT
    class << self
      def enabled?
      end
    end
  end
end

module Kernel
  class NoMatchingPatternError < StandardError
  end
end

module URI
  class WS < Generic
  end
end

class SyntaxSuggest
  class LeftRightLexCount
    def count_lex(_)
    end

    def missing
    end
  end

  class LexAll
    def initialize(source:)
    end

    def each(&block)
    end
  end

  class ExplainSyntax
    def initialize(code_lines:)
    end

    def call
    end
  end

  class CodeLine
    def self.from_source(source)
    end
  end
end
