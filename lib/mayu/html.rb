# typed: strict

require "yaml"

module Mayu
  module HTML
    extend T::Sig

    data = YAML.load_file(File.join(File.dirname(__FILE__), "html.yaml"))
    # Source:
    # https://raw.githubusercontent.com/sindresorhus/html-tags/ff16c695dcf77e1973d17941c36af6ceda4bda10/html-tags-void.json
    VOID_TAGS = T.let(data.fetch(:VOID_TAGS).freeze, T::Array[Symbol])
    # Source:
    # https://raw.githubusercontent.com/sindresorhus/html-tags/ff16c695dcf77e1973d17941c36af6ceda4bda10/html-tags.json
    TAGS = T.let(data.fetch(:TAGS).freeze, T::Array[Symbol])
    # Source:
    # https://raw.githubusercontent.com/wooorm/html-element-attributes/270d8cec96afc251e1501ea5b8e16ad52b8bf875/index.js
    GLOBAL_ATTRIBUTES = T.let(data.fetch(:GLOBAL_ATTRIBUTES).freeze, T::Array[Symbol])
    # Source:
    # https://raw.githubusercontent.com/wooorm/html-event-attributes/b6ee29864ca378f5084980445abed418ef0f1ab9/index.js
    EVENT_HANDLER_ATTRIBUTES = T.let(data.fetch(:EVENT_HANDLER_ATTRIBUTES).freeze, T::Array[Symbol])
    # Source:
    # https://raw.githubusercontent.com/wooorm/html-element-attributes/270d8cec96afc251e1501ea5b8e16ad52b8bf875/index.js
    ATTRIBUTES = T.let(data.fetch(:ATTRIBUTES).freeze, T::Hash[Symbol, T::Array[Symbol]])
    # Source:
    # https://gist.githubusercontent.com/ArjanSchouten/0b8574a6ad7f5065a5e7/raw/bf4d4a6becc3bd8e9840839971011db87e5ec68c/HTML%2520boolean%2520attributes%2520list
    BOOLEAN_ATTRIBUTES = T.let(data.fetch(:BOOLEAN_ATTRIBUTES).freeze, T::Array[Symbol])

    sig { params(tag: Symbol).returns(T::Boolean) }
    def self.void_tag?(tag)
      VOID_TAGS.include?(tag)
    end

    sig { params(tag: Symbol).returns(T::Array[Symbol]) }
    def self.attributes_for(tag)
      GLOBAL_ATTRIBUTES + EVENT_HANDLER_ATTRIBUTES + ATTRIBUTES.fetch(tag, [])
    end

    sig { params(attribute: Symbol).returns(T::Boolean) }
    def self.boolean_attribute?(attribute)
      BOOLEAN_ATTRIBUTES.include?(attribute)
    end

    sig { params(attribute: Symbol).returns(T::Boolean) }
    def self.event_handler_attribute?(attribute)
      EVENT_HANDLER_ATTRIBUTES.include?(attribute)
    end
  end
end
