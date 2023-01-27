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
