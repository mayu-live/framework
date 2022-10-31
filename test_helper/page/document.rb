# typed: strict
# frozen_string_literal: true

require "nokogiri"

module Mayu
  module TestHelper
    class Page
      class Document
        extend T::Sig

        sig { void }
        def initialize
          @doc =
            T.let(
              Nokogiri::HTML5::DocumentFragment.parse(""),
              Nokogiri::HTML5::DocumentFragment
            )
        end

        sig { params(html: String).void }
        def replace_html(html)
          @doc = render_document(html)
        end

        sig { params(rule: String).returns(T.nilable(Nokogiri::XML::Element)) }
        def at_css(rule)
          @doc.at_css(rule)
        end

        sig { returns(String) }
        def to_html
          @doc.to_html
        end

        private

        sig { params(html: String).returns(Nokogiri::HTML5::DocumentFragment) }
        def render_document(html)
          Nokogiri::HTML5::DocumentFragment
            .parse(html)
            .tap { validate_doc(_1, html) }
            .tap { remove_css_hashes(_1) }
            .tap { remove_mayu_id(_1) }
        end

        sig do
          params(doc: Nokogiri::HTML5::DocumentFragment, html: String).void
        end
        def validate_doc(doc, html)
          doc.errors.each do |error|
            puts "\e[31m#{error}\e[0m"
            puts format("\e[31m%s\e[0m", error.message)
            puts format("%s\e[0m", html.dup.insert(error.column, "\e[33m"))
          end
        end

        sig { params(doc: Nokogiri::HTML5::DocumentFragment).void }
        def remove_mayu_id(doc)
          doc
            .css("[data-mayu-id]")
            .each { |elem| elem.remove_attribute("data-mayu-id") }
        end

        sig { params(doc: Nokogiri::HTML5::DocumentFragment).void }
        def remove_css_hashes(doc)
          doc
            .css("[class]")
            .each { |elem| elem["class"] = elem["class"].gsub(/\?[^$\s]+/, "") }
        end
      end
    end
  end
end
