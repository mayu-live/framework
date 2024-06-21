#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "pry"
require "minitest/autorun"
require_relative "css"

class Mayu::Modules::Loaders::Transformers::CSS::Test < Minitest::Test
  Dir[File.join(__dir__, "__test__", "css", "*.in.css")].each do |haml|
    basename = File.basename(haml).split(".", 2).first
    ruby = File.join(File.dirname(haml), basename + ".out.rb")

    define_method :"test_#{basename}" do
      output =
        File
          .read(haml)
          .then do
            Mayu::Modules::Loaders::Transformers::CSS.transform_inline(
              "/app/components/Test.css",
              _1
            )
          end
          .then { SyntaxTree::Formatter.format("", _1) }

      if File.exist?(ruby)
        assert_equal(
          File.read(ruby).strip,
          output.strip,
          "#{ruby} doesn't match transformed output"
        )
      else
        puts "\e[33mWriting #{ruby}\e[0m"
        File.write(ruby, output)
      end
    end
  end
end
