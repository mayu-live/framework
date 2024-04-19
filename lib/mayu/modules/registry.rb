# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "securerandom"

module Mayu
  module Modules
    module Registry
      PREFIX = "Mod_"
      # DIVISION_SLASH = "\u2215"
      # ONE_DOT_LEADER = "\u2024"
      REPLACEMENTS = {
        # "/" => DIVISION_SLASH,
        # "." => ONE_DOT_LEADER,
      }

      def self.[](path)
        const_name = path_to_const_name(path)
        const_defined?(const_name) && const_get(const_name)
      end

      def self.[]=(path, obj)
        const_name = path_to_const_name(path)
        const_set(const_name, obj)
        # puts "\e[33mSetting #{name}::#{const_name} = #{obj.inspect}\e[0m"
        obj
      end

      def self.delete(path)
        const_name = path_to_const_name(path)
        const_defined?(const_name) && remove_const(path_to_const_name(path))
      end

      def self.path_to_const_name(path)
        PREFIX +
          path
            .to_s
            .gsub(/[^[a-zA-Z0-9]]/) do |char|
              REPLACEMENTS.fetch(char) { "_#{_1.ord}_" }
            end
      end

      def self.modules
        constants.filter { _1.start_with?(PREFIX) }.map { const_get(_1) }
      end
    end
  end
end
