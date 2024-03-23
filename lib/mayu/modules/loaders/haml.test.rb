#!/usr/bin/env ruby -rbundler/setup

require "minitest/autorun"

require_relative "../loaders"
require_relative "haml"

class Mayu::Modules::Loaders::Haml::Test < Minitest::Test
  Dir[File.join(__dir__, "__test__", "haml", "*.haml")].each do |haml|
    basename = File.basename(haml, ".*")
    ruby = File.join(File.dirname(haml), basename + ".rb")

    root = File.join(__dir__, "__test__", "haml")

    define_method :"test_#{basename}" do
      output =
        Mayu::Modules::Loaders::Haml[
          component_base_class: "Mayu::Component::Base",
          factory: "Mayu::Descriptors::H",
        ].call(
          Mayu::Modules::Loaders::LoadingFile[root, File.basename(haml)]
        ).source

      if File.exist?(ruby)
        assert_equal(File.read(ruby), output)
      else
        puts "\e[33mWriting #{ruby}\e[0m"
        File.write(ruby, output)
      end
    end
  end
end
