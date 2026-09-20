# frozen_string_literal: true

module Mayu
  module Test
    class Page
      include QueryMethods

      DEFAULT_SETTLE_TIMEOUT = 1.0

      class NodeNotFoundError < StandardError
      end

      class NoListenerError < StandardError
      end

      class SettleTimeoutError < StandardError
      end

      Node =
        Data.define(:page, :node) do
          include QueryMethods

          def name = node.name
          def [](attr) = node.get(attr.to_s)

          def attributes
            return {} unless node.respond_to?(:attributes)

            node.attributes.map { [it.name, it.value] }.to_h
          end

          def text = node.text
          alias_method :content, :text

          def traverse(&)
            yield self
            node.each_node { |child| yield self.class.new(page, child) }
          end

          def at_xpath(query)
            result = node.at_xpath(query)
            self.class.new(page, result) if result
          end

          def find(&)
            return self if yield node

            node.each_node do |child|
              return self.class.new(page, child) if yield child
            end
            nil
          end

          def find!(&)
            find(&) or raise NodeNotFoundError
          end

          def click
            target = {name: attributes["name"], value: attributes["value"]}
            page.fire_event(:click, self, target:, currentTarget: target)
            self
          end

          def input(value)
            node.set("value", value.to_s) if node.is_a?(Oga::XML::Element)
            page.fire_event(:input, self, currentTarget: {value: value.to_s})
            self
          end

          def type(value)
            value.to_s.each_char.reduce(self["value"].to_s) do |current, char|
              input(current + char)
              yield self if block_given?
              current + char
            end
            self
          end

          alias_method :type_input, :type

          private

          def query_page = page
          def query_container = node
        end

      attr_reader :commands

      def initialize(engine, settle_timeout: DEFAULT_SETTLE_TIMEOUT)
        @engine = engine
        @settle_timeout = settle_timeout
        @nodes = {}
        @listener_bindings = {}
        @doc = Oga.parse_html(@engine.render)
        @commands = []
        setup_tree(@doc, @engine.dom_id_tree)
        @engine.listener_commands.each { |command| apply_command(command) }
      end

      def fragment = @doc
      def html = @doc.to_xml

      def start
        @task ||=
          Async do
            @engine.start

            loop do
              batch = @engine.dequeue_batch
              each_command(batch) do |command|
                @commands << command
                apply_command(command)
              end
              batch.complete
            end
          ensure
            @engine.stop
            @task = nil
          end
      end

      def stop
        @task&.stop
        @task = nil
        @engine.stop
        self
      end

      def settle
        Async::Task.current.with_timeout(@settle_timeout) { @engine.synchronize }
        self
      rescue Async::TimeoutError
        raise SettleTimeoutError,
          "Mayu page did not settle within #{@settle_timeout}s\n\n#{html}"
      end

      def step
        interactive = Fiber[:test_enable_step] && $stdout.tty?
        return settle unless interactive

        puts format(
          "\e[H\e[2J%s\n\e[3m %s \e[0m\n",
          self.class.format_html(html),
          "Press return to step"
        )
        gets
        settle
      end

      def traverse(&) = Node.new(self, @doc).traverse(&)
      def find(...) = Node.new(self, @doc).find(...)
      def find!(...) = Node.new(self, @doc).find!(...)

      def at_xpath(query)
        result = @doc.at_xpath(query)
        Node.new(self, result) if result
      end

      def get_component(klass)
        components = get_all_components(klass)

        case components.length
        when 1 then components.first
        when 0
          raise ComponentNotFoundError, "Could not find a #{klass} component"
        else
          raise MultipleComponentsFoundError,
            "Found #{components.length} #{klass} components; expected exactly one"
        end
      end

      def query_component(klass)
        components = get_all_components(klass)

        case components.length
        when 0 then nil
        when 1 then components.first
        else
          raise MultipleComponentsFoundError,
            "Found #{components.length} #{klass} components; expected at most one"
        end
      end

      def get_all_components(klass)
        component_vnodes(klass).map { ComponentHandle.new(it) }
      end

      def fire_event(event, node, payload = nil, **fields)
        unless node.is_a?(Node) && node.page.equal?(self)
          raise ArgumentError, "fire_event expects a node from this rendered page"
        end

        event = event.to_s.delete_prefix("on")
        dom_id = @nodes.key(node.node)
        id = @listener_bindings[[dom_id, event]]
        unless id
          raise NoListenerError,
            "#{node.name} does not have a Mayu on#{event} listener"
        end

        payload = payload ? payload.merge(fields) : fields
        callback(id, payload)
      end

      def callback(id, payload = {})
        raise NoListenerError, "Missing callback listener ID" unless id

        completion = @engine.callback(id, payload)
        Async::Task.current.with_timeout(@settle_timeout) do
          completion&.dequeue
          @engine.synchronize
        end
        self
      rescue Async::TimeoutError
        raise SettleTimeoutError,
          "Mayu callback #{id.inspect} did not settle within #{@settle_timeout}s\n\n#{html}"
      end

      def emit(event)
        event.call(@engine)
        settle
      end

      def self.format_html(source)
        theme = Rouge::Themes::Gruvbox.dark!
        formatter = Rouge::Formatters::Terminal256.new(theme)
        lexer = Rouge::Lexers::HTML.new
        formatter.format(lexer.lex(source))
      end

      private

      def query_page = self
      def query_container = @doc

      def component_vnodes(klass)
        components = []

        @engine.root.send(:traverse) do |node|
          next unless node.is_a?(Mayu::Runtime::VNodes::VComponent)

          instance = node.instance_variable_get(:@instance)
          components << node if instance.is_a?(klass)
        end

        components
      end

      def each_command(value, &block)
        case value
        when Mayu::Runtime::Commands::ViewTransition
          each_command(value.batch, &block)
        when Mayu::Runtime::Batch
          value.commands.each { |command| each_command(command, &block) }
        else
          yield value
        end
      end

      def apply_command(command)
        case command
        in Mayu::Runtime::Commands::Initialize[id_tree:]
          @nodes.clear
          @listener_bindings.clear
          setup_tree(@doc, id_tree)
        in Mayu::Runtime::Commands::CreateTree[html:, tree:]
          nodes = Oga.parse_html(html).children
          nodes.zip(tree).each { |node, id_node| setup_tree(node, id_node) }
        in Mayu::Runtime::Commands::CreateElement[id:, type:]
          @nodes[id] = Oga::XML::Element.new(name: type.to_s)
        in Mayu::Runtime::Commands::CreateTextNode[id:, content:]
          @nodes[id] = Oga::XML::Text.new(text: content.to_s)
        in Mayu::Runtime::Commands::CreateComment[id:, content:]
          @nodes[id] = Oga::XML::Comment.new(text: content.to_s)
        in Mayu::Runtime::Commands::SetTextContent[id:, content:]
          fetch_node!(id).text = content.to_s
        in Mayu::Runtime::Commands::ReplaceData[id:, offset:, count:, data:]
          node = fetch_node!(id)
          node.text = node.text.dup.tap { it[offset, count] = data }
        in Mayu::Runtime::Commands::InsertData[id:, offset:, data:]
          node = fetch_node!(id)
          node.text = node.text.dup.insert(offset, data)
        in Mayu::Runtime::Commands::DeleteData[id:, offset:, count:]
          node = fetch_node!(id)
          node.text = node.text.dup.tap { it.slice!(offset, count) }
        in Mayu::Runtime::Commands::SetAttribute[id:, name:, value:]
          fetch_node!(id).set(normalize_attribute_name(name), value.to_s)
        in Mayu::Runtime::Commands::RemoveAttribute[id:, name:]
          fetch_node!(id).unset(normalize_attribute_name(name))
        in Mayu::Runtime::Commands::SetListener[id:, name:, listener_id:]
          @listener_bindings[[id, name.to_s]] = listener_id
        in Mayu::Runtime::Commands::RemoveListener[id:, name:, listener_id:]
          key = [id, name.to_s]
          @listener_bindings.delete(key) if @listener_bindings[key] == listener_id
        in Mayu::Runtime::Commands::SetClassName[id:, class_name:]
          fetch_node!(id).set("class", class_name.to_s)
        in Mayu::Runtime::Commands::AddClass[id:, classes:]
          node = fetch_node!(id)
          node.set("class", (node.get("class").to_s.split | classes).join(" "))
        in Mayu::Runtime::Commands::RemoveClass[id:, classes:]
          node = fetch_node!(id)
          node.set("class", (node.get("class").to_s.split - classes).join(" "))
        in Mayu::Runtime::Commands::SetCSSProperty[id:, name:, value:]
          set_css_property(fetch_node!(id), name, value)
        in Mayu::Runtime::Commands::RemoveCSSProperty[id:, name:]
          set_css_property(fetch_node!(id), name, nil)
        in Mayu::Runtime::Commands::ReplaceChildren[id:, child_ids:]
          node = fetch_node!(id)
          node.children = Oga::XML::NodeSet.new(child_ids.map { fetch_node!(it) })
        in Mayu::Runtime::Commands::RemoveNode[id:]
          remove_node(id)
        else
          nil
        end
      end

      def normalize_attribute_name(name)
        return "value" if name.to_s == "initial_value"

        name.to_s.tr("_", "-")
      end

      def set_css_property(node, name, value)
        styles =
          node.get("style").to_s.split(";").filter_map do |declaration|
            key, current = declaration.split(":", 2).map(&:strip)
            [key, current] unless key.to_s.empty?
          end.to_h
        value.nil? ? styles.delete(name.to_s) : styles[name.to_s] = value.to_s
        node.set("style", styles.map { |key, current| "#{key}:#{current}" }.join(";"))
      end

      def setup_tree(dom_node, id_node)
        return unless dom_node && id_node

        if dom_node.is_a?(Oga::XML::Element) &&
            dom_node.name != id_node.name.downcase
          raise "#{id_node.id} should be #{id_node.name.inspect}, but found #{dom_node.name.inspect}"
        end

        @nodes[id_node.id] = dom_node
        dom_node.children.reject { it.is_a?(Oga::XML::Document) }
          .reject { it.is_a?(Oga::XML::Text) && it.text == "\n" }
          .zip(id_node.children || [])
          .each { |dom_child, id_child| setup_tree(dom_child, id_child) }
      end

      def remove_node(id)
        node = @nodes.delete(id)
        return unless node

        removed_ids = [id]
        node.each_node do |child|
          pair = @nodes.find { |_node_id, candidate| candidate.equal?(child) }
          if pair
            removed_ids << pair.first
            @nodes.delete(pair.first)
          end
        end

        @listener_bindings.delete_if do |(node_id, _event), _listener_id|
          removed_ids.include?(node_id)
        end
      end

      def fetch_node!(id)
        @nodes.fetch(id) { raise "Could not find node with id #{id.inspect}" }
      end
    end
  end
end
