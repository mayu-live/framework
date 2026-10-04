# frozen_string_literal: true

Heading = import("/components/Layout/Heading")

class MarkdownHeadingBase < Mayu::Component::Base
  def render
    H[Heading, *@__children.descriptors, **@__props.merge(level: self.class::LEVEL)]
  end
end

(1..6).each do |level|
  const_set("H#{level}", Class.new(MarkdownHeadingBase) { const_set(:LEVEL, level) })
end
