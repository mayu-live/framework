# frozen_string_literal: true
# typed: strict

require_relative "types/nil"
require_relative "types/component"
require_relative "types/image"
require_relative "types/stylesheet"
require_relative "types/javascript"
require_relative "types/svg"

module Mayu
  module Resources
    module Types
      extend T::Sig

      sig { params(path: String).returns(T.class_of(Types::Base)) }
      def self.for_path(path)
        case path
        when /\.rb\z/
          return Component
        when /\.haml\z/
          return Component
        when /\.js\z/
          return JavaScript
        when /\.css\z/
          return Stylesheet
        when /\.(png|jpe?g|gif|webp)$\z/
          return Image
        when /\.svg\z/
          return SVG
        end

        raise "No type for #{path}"
      end
    end
  end
end
