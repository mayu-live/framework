# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../../../component/base"

module Mayu
  module Runtime
    module VNodes2
      module InternalComponents
        class Base < Mayu::Component::Base
          def self.module_path = "(internal)::#{name}"
        end
      end
    end
  end
end
