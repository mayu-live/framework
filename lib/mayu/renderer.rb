# typed: strict

require_relative "renderer/vdom"

module Mayu
  module Renderer
    extend VDOM::DescriptorHelper
  end
end
