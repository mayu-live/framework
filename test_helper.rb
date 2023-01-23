# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "minitest/reporters"
require "pry"

$LOAD_PATH.unshift(File.join(__dir__, "lib"))

Minitest::Reporters.use!(
  Minitest::Reporters::DefaultReporter.new,
  ENV,
  Minitest.backtrace_filter
)

require_relative "lib/mayu/metrics"
require_relative "lib/mayu/app_metrics"

module Mayu
  module TestHelper
    extend T::Sig

    autoload :Components, "test_helper/components"
    autoload :Formatting, "test_helper/formatting"
    autoload :Page, "test_helper/page"
    autoload :VDOM, "test_helper/vdom"

    sig do
      params(
        component: T.class_of(Mayu::Component::Base),
        props: T.untyped,
        block: T.proc.params(arg0: Page).void
      ).void
    end
    def self.test_component(component, **props, &block)
      Async do
        Page.run do |page|
          page.render(Mayu::VDOM::Descriptor[component, **props])
          yield page
        end
      end
    end

    sig { returns(Mayu::AppMetrics) }
    def self.metrics
      $metrics ||= Mayu::AppMetrics.setup(Prometheus::Client.registry)
    end

    sig { returns(Mayu::VDOM::VTree) }
    def self.setup_vtree
      TestHelper::VDOM.setup_vtree
    end

    sig do
      params(file: String, line: Integer, haml: String).returns(
        T.class_of(Mayu::Component::Base)
      )
    end
    def self.haml_to_component(file, line, haml)
      TestHelper::Components.haml_to_component(haml, file:, line:)
    end

    sig { params(xml: String).returns(String) }
    def self.format_xml_plain(xml)
      Formatting.format_xml_plain(xml)
    end

    sig { params(source: String, language: Symbol).returns(String) }
    def self.format_source(source, language)
      Formatting.format_source(source, language)
    end
  end
end
