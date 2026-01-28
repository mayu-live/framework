# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "base"

module Mayu
  module Runtime
    module VNodes2
      module InternalComponents
        class Head < Base
          def render
            H[:__head, *fixed_tags, *user_tags]
          end

          private

          def fixed_tags
            [
              H[:meta, charset: "utf-8"],
              runtime_script,
              *stylesheet_links
            ].compact
          end

          def runtime_script
            return unless runtime_js = @__props[:runtime_js]

            H[
              :script,
              type: "module",
              src: runtime_js,
              async: true,
              key: "runtime_js"
            ]
          end

          def stylesheet_links
            @__props[:styles].map do |filename|
              H[
                :link,
                key: filename,
                rel: "stylesheet",
                href: "/.mayu/assets/#{filename}"
              ]
            end
          end

          def user_tags
            keyed = {}
            order = []

            @__props[:descriptors].each_with_index do |descriptor, index|
              key = head_key_for(descriptor, index)
              next unless key

              order << key unless keyed.key?(key)
              keyed[key] = descriptor
            end

            order.map { |key| keyed[key].with(key:) }
          end

          def head_key_for(descriptor, index)
            case descriptor
            in Descriptors::Element[type: :meta, props: { charset: }]
              puts "\e[31m%meta(charset=#{charset.inspect}) ignored\e[0m"
              nil
            in Descriptors::Element[type: :meta, props: { name: }]
              "meta-name-#{name}"
            in Descriptors::Element[type: :meta, props: { property: }]
              "meta-property-#{property}"
            in Descriptors::Element[type: :title]
              "title"
            in Descriptors::Element[type: :link, key:]
              "link-key-#{key}"
            in Descriptors::Element[type: :link]
              "link-idx-#{index}"
            else
              puts "\e[31mUnsupported %head node: #{descriptor.inspect}\e[0m"
              nil
            end
          end
        end
      end
    end
  end
end
