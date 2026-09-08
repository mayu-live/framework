# frozen_string_literal: true

require "set"

module Mayu
  module Test
    class QueryError < StandardError
    end

    class StaticAccessibility
      EMPTY_TEXT_PLACEHOLDER = "\u200B"
      TEXTBOX_INPUT_TYPES = %w[email password search tel text url].freeze
      BUTTON_INPUT_TYPES = %w[button image reset submit].freeze
      LABELABLE_TAGS = %w[button input meter output progress select textarea].freeze

      def initialize(document)
        @document = document
      end

      def role(node)
        explicit = node.get("role").to_s.split.first
        return explicit unless explicit.to_s.empty?

        native_role(node)
      end

      def name(node, seen = Set.new)
        added = seen.add?(node.object_id)
        return "" unless added

        aria_label = node.get("aria-label")
        return normalize(aria_label) unless aria_label.nil?

        labelled_by =
          node
            .get("aria-labelledby")
            .to_s
            .split
            .filter_map do |id|
              reference = document.at_css("##{id}")
              name(reference, seen) if reference
            end
        return normalize(labelled_by.join(" ")) unless labelled_by.empty?

        labels = labels_for(node).map { visible_text(it) }
        return normalize(labels.join(" ")) unless labels.empty?

        if node.name == "img" || input_type(node) == "image"
          return normalize(node.get("alt"))
        end
        if node.name == "input" && BUTTON_INPUT_TYPES.include?(input_type(node))
          return normalize(node.get("value") || input_type(node).capitalize)
        end

        visible_text(node)
      ensure
        seen.delete(node.object_id) if added
      end

      def hidden?(node)
        current = node
        while current.is_a?(Oga::XML::Element)
          return true if current.attribute("hidden")
          return true if current.get("aria-hidden").to_s.casecmp?("true")
          if current.name == "input" && input_type(current) == "hidden"
            return true
          end

          current = current.parent
        end
        false
      end

      def visible_text(node)
        text =
          node.children.filter_map do |child|
            if child.is_a?(Oga::XML::Text)
              child.text
            elsif child.is_a?(Oga::XML::Element) && !hidden?(child) &&
                  !%w[script style template].include?(child.name)
              visible_text(child)
            end
          end
        normalize(text.join(" "))
      end

      def normalize(value)
        value.to_s.delete(EMPTY_TEXT_PLACEHOLDER).gsub(/\s+/, " ").strip
      end

      private

      attr_reader :document

      def native_role(node)
        case node.name
        when "a", "area"
          "link" if node.attribute("href")
        when "button", "summary"
          "button"
        when "h1", "h2", "h3", "h4", "h5", "h6"
          "heading"
        when "ul", "ol", "menu"
          "list"
        when "li"
          "listitem"
        when "input"
          input_role(node)
        when "textarea"
          "textbox"
        when "select"
          if node.attribute("multiple") || node.get("size").to_i > 1
            "listbox"
          else
            "combobox"
          end
        when "option"
          "option"
        when "img"
          "img" unless node.get("alt") == ""
        when "progress"
          "progressbar"
        when "meter"
          "meter"
        when "output"
          "status"
        when "nav"
          "navigation"
        when "main"
          "main"
        when "aside"
          "complementary"
        when "dialog"
          "dialog"
        when "table"
          "table"
        when "tr"
          "row"
        when "th"
          node.get("scope") == "row" ? "rowheader" : "columnheader"
        when "td"
          "cell"
        end
      end

      def input_role(node)
        type = input_type(node)
        return "button" if BUTTON_INPUT_TYPES.include?(type)
        return "checkbox" if type == "checkbox"
        return "radio" if type == "radio"
        return "slider" if type == "range"
        return "spinbutton" if type == "number"
        return "searchbox" if type == "search"
        return "textbox" if TEXTBOX_INPUT_TYPES.include?(type)
      end

      def input_type(node)
        node.name == "input" ? (node.get("type") || "text").downcase : nil
      end

      def labels_for(node)
        return [] unless LABELABLE_TAGS.include?(node.name)

        labels = []
        id = node.get("id")
        unless id.to_s.empty?
          labels.concat(
            document.css("label").select do |label|
              label.get("for") == id && !hidden?(label)
            end
          )
        end

        current = node.parent
        while current
          if current.is_a?(Oga::XML::Element) && current.name == "label" &&
               !hidden?(current)
            labels << current
            break
          end
          current = current.respond_to?(:parent) ? current.parent : nil
        end
        labels.uniq
      end
    end

    module QueryMethods
      def get_by_role(role, name: nil)
        query_scope.get_by_role(role, name:)
      end

      def query_by_role(role, name: nil)
        query_scope.query_by_role(role, name:)
      end

      def get_all_by_role(role, name: nil)
        query_scope.get_all_by_role(role, name:)
      end

      def query_all_by_role(role, name: nil)
        query_scope.query_all_by_role(role, name:)
      end

      def get_by_text(matcher) = query_scope.get_by_text(matcher)
      def query_by_text(matcher) = query_scope.query_by_text(matcher)
      def get_all_by_text(matcher) = query_scope.get_all_by_text(matcher)
      def query_all_by_text(matcher) = query_scope.query_all_by_text(matcher)
      def get_by_css(selector) = query_scope.get_by_css(selector)
      def query_by_css(selector) = query_scope.query_by_css(selector)
      def get_all_by_css(selector) = query_scope.get_all_by_css(selector)
      def query_all_by_css(selector) = query_scope.query_all_by_css(selector)

      def has_role?(role, name: nil)
        query_scope.has_role?(role, name:)
      end

      def has_text?(matcher) = query_scope.has_text?(matcher)
      def has_css?(selector) = query_scope.has_css?(selector)
      def within(node) = query_scope.within(node)

      private

      def query_scope
        QueryScope.new(query_page, query_container)
      end
    end

    class QueryScope
      include QueryMethods

      def initialize(page, container)
        @page = page
        @container = container
      end

      def within(node)
        unless node.is_a?(Page::Node) && node.page.equal?(page) &&
                 contains?(node.node)
          raise ArgumentError, "within expects a node from this rendered page"
        end

        self.class.new(page, node.node)
      end

      private

      attr_reader :page, :container

      def query_page = page
      def query_container = container

      def role_query(method_name, role, name: nil)
        role = role.to_s
        candidates =
          elements.select do |node|
            !accessibility.hidden?(node) && accessibility.role(node) == role
          end
        matches =
          if name
            candidates.select do |node|
              text_matches?(accessibility.name(node), name)
            end
          else
            candidates
          end
        resolve(
          method_name,
          [role.to_sym, { name: }],
          matches,
          candidates: name ? candidates : matches
        ) do |node|
          %(role=#{role.inspect}, name=#{accessibility.name(node).inspect}, #{node.to_xml})
        end
      end

      def text_query(method_name, matcher)
        candidates =
          elements.reject do |node|
            accessibility.hidden?(node) ||
              %w[script style template].include?(node.name)
          end
        matches =
          candidates.select do |node|
            text_matches?(accessibility.visible_text(node), matcher)
          end
        matches.reject! do |node|
          node.css("*").any? do |descendant|
            !accessibility.hidden?(descendant) &&
              text_matches?(accessibility.visible_text(descendant), matcher)
          end
        end
        resolve(method_name, [matcher], matches)
      end

      def css_query(method_name, selector)
        resolve(method_name, [selector], container.css(selector).to_a)
      end

      public

      def get_by_role(role, name: nil)
        role_query(:get_by_role, role, name:)
      end

      def query_by_role(role, name: nil)
        role_query(:query_by_role, role, name:)
      end

      def get_all_by_role(role, name: nil)
        role_query(:get_all_by_role, role, name:)
      end

      def query_all_by_role(role, name: nil)
        role_query(:query_all_by_role, role, name:)
      end

      def get_by_text(matcher) = text_query(:get_by_text, matcher)
      def query_by_text(matcher) = text_query(:query_by_text, matcher)
      def get_all_by_text(matcher) = text_query(:get_all_by_text, matcher)
      def query_all_by_text(matcher) = text_query(:query_all_by_text, matcher)
      def get_by_css(selector) = css_query(:get_by_css, selector)
      def query_by_css(selector) = css_query(:query_by_css, selector)
      def get_all_by_css(selector) = css_query(:get_all_by_css, selector)
      def query_all_by_css(selector) = css_query(:query_all_by_css, selector)

      def has_role?(role, name: nil)
        !query_all_by_role(role, name:).empty?
      end

      def has_text?(matcher) = !query_all_by_text(matcher).empty?
      def has_css?(selector) = !query_all_by_css(selector).empty?

      private

      def elements
        container.css("*").select { it.is_a?(Oga::XML::Element) }
      end

      def accessibility
        @accessibility ||= StaticAccessibility.new(page.fragment)
      end

      def text_matches?(actual, matcher)
        case matcher
        when String
          actual == accessibility.normalize(matcher)
        when Regexp
          matcher.match?(actual)
        else
          raise ArgumentError, "text matcher must be a String or Regexp"
        end
      end

      def resolve(method_name, arguments, matches, candidates: matches, &)
        return wrap(matches) if method_name.to_s.start_with?("query_all")
        if method_name.to_s.start_with?("get_all")
          return wrap(matches) unless matches.empty?
        end
        return wrap(matches.first) if matches.length == 1
        if matches.empty? && method_name.to_s.start_with?("query_by")
          return nil
        end

        expectation =
          method_name.to_s.start_with?("get_all") ? "one or more" :
            "exactly one"
        reason = matches.empty? ? "No matches found" :
          "Found #{matches.length} matches"
        query = format_query(method_name, arguments)
        candidate_nodes = matches.empty? ? candidates : matches
        raise QueryError,
              diagnostic(query, reason, expectation, candidate_nodes, &)
      end

      def wrap(value)
        if value.is_a?(Array) || value.is_a?(Oga::XML::NodeSet)
          value.map { Page::Node.new(page, it) }
        else
          Page::Node.new(page, value)
        end
      end

      def format_query(method_name, arguments)
        values =
          arguments.flat_map do |argument|
            if argument.is_a?(Hash)
              argument.filter_map do |key, value|
                "#{key}: #{value.inspect}" unless value.nil?
              end
            else
              argument.inspect
            end
          end
        "#{method_name}(#{values.join(", ")})"
      end

      def diagnostic(query, reason, expectation, candidates)
        lines = ["Query: #{query}", "#{reason}; expected #{expectation}."]
        unless candidates.empty?
          lines << "" << "Candidates:"
          candidates.each_with_index do |node, index|
            description = block_given? ? yield(node) : node.to_xml
            lines << "  #{index + 1}. #{description}"
          end
        end
        lines << "" << "Rendered HTML:" << indent(page.html, "  ")
        lines.join("\n")
      end

      def indent(value, prefix)
        value.lines.map { "#{prefix}#{it}" }.join.rstrip
      end

      def contains?(target)
        return true if container.equal?(target)

        container.each_node.any? { it.equal?(target) }
      end
    end
  end
end
