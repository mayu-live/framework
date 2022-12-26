# typed: strict
# frozen_string_literal: true

require "mayu/component/base"

module Mayu
  module TestHelper
    module Components
      class << self
        extend T::Sig

        sig do
          params(source: String, file: String, line: Integer).returns(
            T.class_of(Mayu::Component::Base)
          )
        end
        def haml_to_component(source, file:, line:)
          result =
            Mayu::Resources::Transformers::Haml.transform(
              content_hash: "test123",
              source: source,
              source_path: get_path_relative_to_root(file),
              source_line: line
            )

          impl = Class.new(Mayu::Component::Base)
          impl.class_eval(result.output, file, line)

          if css = result.css
            classname_proxy =
              Resources::Types::Stylesheet::ClassnameProxy.new(css.classes)
            impl.instance_exec(classname_proxy) do |classname_proxy|
              define_singleton_method(:styles) { classname_proxy }
              define_method(:styles) { classname_proxy }
            end
          end

          impl
        end

        sig { params(path: String).returns(String) }
        def get_path_relative_to_root(path)
          root = File.expand_path(File.join(__dir__, ".."))

          Pathname.new(path).relative_path_from(root).to_s
        end
      end
    end
  end
end
