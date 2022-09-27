# typed: strict
# frozen_string_literal: true

require_relative "routing/routes"
require_relative "routing/builder"
require_relative "routing/matcher"

module Mayu
  module Routing
  end
end

# root = Routing::Builder.build(File.join(__dir__, "example2", "app", "pages"))
# matcher = Routing::Matcher.new(root)
# p matcher.match("/pokemon")
# p matcher.match("/pokemon/123")
# p matcher.match("/pokemon/123/asd")
