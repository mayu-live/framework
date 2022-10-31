# typed: strict
# frozen_string_literal: true

require "mayu/vdom/vtree"
require_relative "page/document"

module Mayu
  module TestHelper
    class Page
      class UserEvent
        extend T::Sig

        sig { returns(String) }
        attr_reader :type
        sig { returns(T::Hash[String, T.untyped]) }
        attr_reader :payload

        sig { params(type: String, payload: T::Hash[String, T.untyped]).void }
        def initialize(type, payload = {})
          @type = type
          @payload =
            T.let(payload.merge("type" => type), T::Hash[String, T.untyped])
          freeze
        end
      end

      extend T::Sig

      DEFAULT_UPDATE_TIMEOUT = 0.5
      CALLBACK_ID_RE = /\AMayu\.handle\(event,'(?<callback_id>\w+)'\)\z/

      sig { params(block: T.proc.params(arg0: Page).void).void }
      def self.run(&block)
        page = Page.new
        updater_task = page.run
        yield page
      ensure
        updater_task&.stop
      end

      sig { params(task: Async::Task).void }
      def initialize(task: Async::Task.current)
        @vtree = T.let(TestHelper.setup_vtree, Mayu::VDOM::VTree)
        @on_update_finished =
          T.let(Async::Notification.new, Async::Notification)
        @doc = T.let(Document.new, Document)
      end

      sig { returns(Async::Task) }
      def run
        Mayu::VDOM::VTree::Updater
          .new(@vtree)
          .run do |event, payload|
            if event == :update_finished
              @doc.replace_html(@vtree.to_html)
              @on_update_finished.signal
            else
              # TODO: Handle patch events and apply them
              # just like we do in the browser..
              Console.logger.debug(
                Mayu::VDOM::VTree::Updater,
                event,
                JSON.generate(payload)
              )
            end
          end
      end

      sig { params(descriptor: Mayu::VDOM::Descriptor).void }
      def render(descriptor)
        @vtree.render(descriptor)
        @doc.replace_html(@vtree.to_html)
      end

      sig { params(timeout: Float, task: Async::Task).void }
      def wait_for_update(
        timeout: DEFAULT_UPDATE_TIMEOUT,
        task: Async::Task.current
      )
        task.with_timeout(timeout) do
          @on_update_finished.wait
        rescue Async::TimeoutError
          # noop
        end
      end

      sig { returns(String) }
      def to_html
        Mayu::TestHelper.format_xml_plain(@doc.to_html)
      end

      sig { void }
      def debug!
        Console.logger.info(
          "#{self.class.name}##{__method__}",
          "Caller: #{caller.find { !_1.include?("sorbet-runtime") }}",
          debug_html
        )
      end

      sig { returns(String) }
      def debug_html
        Mayu::TestHelper.format_source(@doc.to_html, :html)
      end

      sig do
        params(
          element: T.nilable(Nokogiri::XML::Element),
          type: Symbol,
          payload: T::Hash[String, String]
        ).void
      end
      def fire_event(element, type, payload = {})
        raise ArgumentError, "element is nil" unless element

        event = UserEvent.new(type.to_s, payload)
        callback_id = callback_id_from_attr(element, "on#{type}")
        @vtree.handle_callback(callback_id, event.payload)
      end

      sig { params(test_id: String).returns(T.nilable(Nokogiri::XML::Element)) }
      def find_by_test_id(test_id)
        @doc.at_css("[data-test-id='#{test_id}']")
      end

      sig { params(rule: String).returns(T.nilable(Nokogiri::XML::Element)) }
      def find_by_css(rule)
        @doc.at_css(rule)
      end

      sig do
        params(element: Nokogiri::XML::Element, attr: String).returns(String)
      end
      def callback_id_from_attr(element, attr)
        if match = CALLBACK_ID_RE.match(element[attr])
          return match[:callback_id].to_s
        end

        $stderr.puts <<~EOF
        \e[7;31mCould not find an #{attr}-handler:\e[0m
        #{Mayu::TestHelper.format_source(element.to_html, :html)}
        EOF
        raise "Element does not have an #{attr}-handler: #{element.to_s}"
      end
    end
  end
end
