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
