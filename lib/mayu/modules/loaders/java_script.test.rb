# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

#!/usr/bin/env ruby -rbundler/setup

require "minitest/autorun"

require_relative "../loaders"
require_relative "java_script"

class Mayu::Modules::Loaders::Haml::Test < Minitest::Test
  Dir[File.join(__dir__, "__test__", "js", "*.js")].each do |js|
    basename = File.basename(js, ".*")
    ruby = File.join(File.dirname(js), basename + ".rb")
    root = File.join(__dir__, "__test__", "js")

    define_method :"test_#{basename}" do
      output =
        Mayu::Modules::Loaders::JavaScript[].call(
          Mayu::Modules::Loaders::LoadingFile[root, File.basename(js)]
        ).source

      if File.exist?(ruby)
        assert_equal(
          File.read(ruby),
          output,
          "#{ruby} doesn't match transformed output"
        )
      else
        puts "\e[33mWriting #{ruby}\e[0m"
        File.write(ruby, output)
      end
    end
  end
end
