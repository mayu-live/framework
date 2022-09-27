# typed: strict
# frozen_string_literal: true

module Mayu
  module Routing
    module Routes
      class Route
        extend T::Sig

        sig { returns(T.nilable(String)) }
        attr_accessor :page
        sig { returns(T.nilable(String)) }
        attr_accessor :layout
        sig { returns(T.nilable(String)) }
        attr_accessor :not_found

        sig { void }
        def initialize
          @page = nil
          @layout = nil
          @not_found = nil
          @named = T.let({}, T::Hash[String, Named])
          @params = T.let([], T::Array[Param])
        end

        sig { params(route: Route).void }
        def add_route(route)
          case route
          when Named
            @named[route.name] = route
          when Param
            @params.push(route)
          else
            raise TypeError, "Unknown route type: #{route.class}"
          end
        end

        sig { params(part: String).returns(T.nilable(Route)) }
        def match(part)
          @named.fetch(part) { @params.find { _1.match?(part) } }
        end

        sig { params(part: String).returns(T::Boolean) }
        def match?(part)
          true
        end
      end

      class Named < Route
        sig { returns(String) }
        attr_reader :name

        sig { params(name: String).void }
        def initialize(name)
          super()
          @name = name
        end

        sig { params(part: String).returns(T::Boolean) }
        def match?(part)
          part == @name
        end
      end

      class Param < Route
        sig { returns(String) }
        attr_reader :name
        sig { returns(Regexp) }
        attr_reader :format

        sig { params(name: String, format: Regexp).void }
        def initialize(name, format: /\A\d+\z/)
          super()
          @name = name
          @format = format
        end

        sig { params(part: String).returns(T::Boolean) }
        def match?(part)
          @format.match?(part)
        end
      end
    end
  end
end
