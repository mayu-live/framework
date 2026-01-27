# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "set"
require_relative "base"
require_relative "vcomponent"

module Mayu
  module Runtime
    module VNodes2
      class VDocument < Base
        class InternalComponentBase < Mayu::Component::Base
          def self.module_path = "(internal)::#{name}"
        end

        class Html < InternalComponentBase
          def render
            H[:html, H[:slot]]
          end
        end

        class Head < InternalComponentBase
          def render
            grouped =
              @__props[:descriptors]
                .group_by do |descriptor|
                  case descriptor
                  in Descriptors::Element[type: :meta, props: { charset: }]
                    puts "\e[31m%meta(charset=#{charset.inspect}) ignored\e[0m"
                    nil
                  in Descriptors::Element[type: :meta, props: { name: }]
                    "meta-name-#{name}"
                  in Descriptors::Element[type: :meta, props: { property: }]
                    "meta-property-#{name}"
                  in Descriptors::Element[type: :title]
                    "title"
                  in Descriptors::Element[type: :link]
                    "link"
                  else
                    puts "\e[31mUnsupported %head node: #{descriptor.inspect}\e[0m"
                    nil
                  end
                end
                .except(nil)
                .transform_values(&:last)

            title = grouped.delete("title")
            tags = grouped.map { |key, element| element.with(key:) }

            styles =
              @__props[:styles].map do |filename|
                H[
                  :link,
                  key: filename,
                  rel: "stylesheet",
                  href: "/.mayu/assets/#{filename}"
                ]
              end

            H[
              :__head,
              H[:meta, charset: "utf-8"],
              if runtime_js = @__props[:runtime_js]
                H[
                  :script,
                  type: "module",
                  src: runtime_js,
                  async: true,
                  key: "runtime_js"
                ]
              end,
              title,
              *styles,
              *tags
            ]
          end
        end

        H = Mayu::Runtime::H

        def initialize(descriptor, parent:, engine:)
          super
          @listeners = {}
          @styles = Set.new
          @head = Set.new
          @html = VComponent.new(init_html, parent: self, engine: @engine)
        end

        def update(patcher, descriptor = nil)
          return unless descriptor
          @descriptor = descriptor
          @html.update(patcher, init_html)
        end

        def write_html(out)
          out << "<!DOCTYPE html>\n"
          @html.write_html(out)
          out << "\n"
        end

        private

        def init_html
          H[Html, init_head, @descriptor]
        end

        def init_head
          H[
            Head,
            runtime_js: @parent.runtime_js,
            styles: @styles,
            descriptors: @head.map(&:children).flatten.compact
          ]
        end
      end
    end
  end
end
