# typed: strict
# frozen_string_literal: true

require "mayu/vdom/vtree"

module Mayu
  module TestHelper
    module VDOM
      class << self
        extend T::Sig

        sig { returns(Mayu::VDOM::VTree) }
        def setup_vtree
          config =
            Mayu::Configuration.from_hash!(
              {
                "mode" => :test,
                "root" => "/laiehbaleihf",
                "secret_key" => "test"
              }
            )

          environment = Mayu::Environment.new(config, TestHelper.metrics)

          environment.instance_eval <<~RUBY
            # sig {params(path: String).returns(Mayu::VDOM::Descriptor)}
            def load_root(path)
              Mayu::VDOM::Descriptor.new(:div)
            end

            # sig {params(path: String).returns(NilClass)}
            def match_route(path)
            end
          RUBY

          session = Mayu::Session.new(environment:, path: "/")
          Mayu::VDOM::VTree.new(session:)
        end
      end
    end
  end
end
