class RouteMatcher
  attr_reader :variables

  def initialize(path, formats: {}, methods: [:get])
    tokens = tokenize(path)
    @regexp = build_regexp(tokens)
    @variables = tokens.select { _1.is_a?(Symbol) }
    @formats = formats
    @methods = methods
  end

  def match(method, path)
    return unless @methods.include?(method)

    @regexp
      .match(path)
      &.named_captures
      .transform_keys(&:to_sym)
      .each do |key, value|
        @formats[key]&.tap { return nil unless _1.match(value) }
      end
  end

  private

  def tokenize(path)
    path
      .delete_prefix("/")
      .split("/")
      .map do |part|
        part.match(/\A\[(?<param>\w+)\]\Z/) ? $~[:param].to_sym : part
      end
  end

  def build_regexp(tokens)
    parts =
      tokens.map do |value|
        case value
        in String
          Regexp.escape(value).to_s
        in Symbol
          "(?<#{value}>[^/]+)"
        end
      end

    Regexp.new('\A\/' + parts.join('\/') + '\Z')
  end
end

class Router
  def initialize
    @routes = []
  end

  def get(path, **formats, &block)
    add_route(RouteMatcher.new(path, formats:, methods: [:get]), &block)
  end

  def match(method, path)
    @routes.each do |route|
      match = route[:matcher].match(method, path)
      next unless match
      route[:block].call(**match)
      return
    end

    raise "No matches"
  end

  def add_route(matcher, &block)
    case block.parameters
    in [[:opt, Symbol]]
      # ok
    else
      block.parameters.each do |type, name|
        case type
        when :key, :keyreq
          unless matcher.variables.include?(name)
            raise ArgumentError,
                  "Unknown variable: #{name}, valid ones are: #{matcher.variables.join(", ")}"
          end
        when :keyrest
          # ok
        when :opt
          raise ArgumentError, "Only keyword arguments supported"
        end
      end
    end

    @routes.push({ matcher:, block: })
  end
end

router = Router.new

router.get "/foo/[id]/lol", id: /\A\d+\Z/ do |id:|
  p id
end

router.match(:get, "/foo/123/lol")
