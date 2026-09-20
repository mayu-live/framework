# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "base"
require_relative "script"

module Mayu
  module Runtime
    module VNodes
      module InternalComponents
        class Head < Base
          Script = InternalComponents::Script

          def render
            H[:__head, *fixed_tags, *user_tags, *asset_tags]
          end

          private

          def fixed_tags
            [H[:meta, charset: "utf-8"]]
          end

          def asset_tags
            [
              *stylesheet_links,
              # A module script without `async` is deferred until parsing is
              # complete. Keeping it after the stylesheets prevents the
              # client from applying its initial update before the browser has
              # discovered the CSS that styles the server-rendered document.
              runtime_script,
              *module_scripts,
              *custom_element_scripts
            ].compact
          end

          def runtime_script
            return unless (runtime_js = @__props[:runtime_js])

            H[
              :script,
              type: "module",
              src: runtime_js,
              key: "runtime_js"
            ]
          end

          def stylesheet_links
            @__props[:styles].map do |stylesheet|
              H[
                :link,
                key: stylesheet,
                rel: "stylesheet",
                href: stylesheet_url(stylesheet)
              ]
            end
          end

          def module_scripts
            (@__props[:scripts] || []).map do |script|
              H[:script, type: "module", src: script, key: "module-#{script}"]
            end
          end

          def stylesheet_url(stylesheet)
            if stylesheet.start_with?("/", "http://", "https://")
              return stylesheet
            end

            "/.mayu/assets/#{stylesheet}"
          end

          def custom_element_scripts
            custom_elements = @__props[:custom_elements] || []
            custom_elements.map do |custom_element|
              H[
                Script,
                key: "custom-element-#{custom_element.name}",
                content: custom_element_script(custom_element)
              ]
            end
          end

          # Klenod appends customElements.define to every custom element
          # module, so importing the module is what registers the element.
          def custom_element_script(custom_element)
            format("import(%p)", custom_element.path.to_s)
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
            in Descriptors::Element[type: :meta, props: {charset:}]
              puts "\e[31m%meta(charset=#{charset.inspect}) ignored\e[0m"
              nil
            in Descriptors::Element[type: :meta, props: {name:}]
              "meta-name-#{name}"
            in Descriptors::Element[type: :meta, props: {property:}]
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
