# frozen_string_literal: true

module Mayu
  module Test
    module Helpers
      def render(renderable, *children, **props, &block)
        descriptor = descriptor_for(renderable, children, props)

        if Async::Task.current?
          render_in_current_task(descriptor, &block)
        elsif block
          Sync { render_in_current_task(descriptor, &block) }
        else
          raise "render without a block requires Mayu::Test::Case"
        end
      end

      def find(*, **)
        find!(*, **)
      rescue Page::NodeNotFoundError
        nil
      end

      def find!(*, **)
        filter = Mayu::Test::Filters::Tag[*, **]
        current_page.find!(&filter)
      end

      def at_xpath(query)
        current_page.at_xpath(query)
      end

      def current_page
        Fiber[:current_test_page] or raise "There is no current page"
      end

      alias_method :screen, :current_page

      def enable_step!
        Fiber[:test_enable_step] = true
      end

      def capture_patches
        offset = current_page.commands.length
        yield
        current_page.commands.drop(offset)
      end

      private

      def descriptor_for(renderable, children, props)
        case renderable
        when Mayu::Runtime::Descriptors::Element,
             Mayu::Runtime::Descriptors::Context,
             Mayu::Runtime::Descriptors::Comment,
             Mayu::Runtime::Descriptors::RawText
          raise ArgumentError, "a descriptor cannot receive children or props" if
            children.any? || props.any?

          renderable
        else
          Mayu::Runtime::H[renderable, *children, **props]
        end
      end

      def render_in_current_task(descriptor)
        module_provider = __test_module_provider if respond_to?(:__test_module_provider, true)
        page =
          Mayu::Test::Page.new(
            Mayu::Runtime.init(
              descriptor,
              metrics: Mayu::Test::FakeMetrics.new,
              runtime_js: "test.js",
              module_provider:
            )
          )
        previous_page = Fiber[:current_test_page]
        Fiber[:current_test_page] = page
        __register_test_page(page) if respond_to?(:__register_test_page, true)
        page.start
        page.settle

        return page unless block_given?

        begin
          yield page
        ensure
          page.stop
          __unregister_test_page(page) if
            respond_to?(:__unregister_test_page, true)
          Fiber[:current_test_page] = previous_page
        end
      end
    end
  end
end
