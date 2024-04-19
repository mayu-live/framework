#!/usr/bin/env ruby -rbundler/setup
require "minitest/autorun"
require_relative "haml"
require_relative "ruby"

class Mayu::Modules::Loaders::Transformers::Haml::Test < Minitest::Test
  Dir[File.join(__dir__, "__test__", "haml", "*.haml")].each do |haml|
    basename = File.basename(haml, ".*")
    ruby = File.join(File.dirname(haml), basename + ".rb")

    define_method :"test_#{basename}" do
      output =
        File
          .read(haml)
          .then do
            Mayu::Modules::Loaders::Transformers::Haml.transform(
              _1,
              haml
            ).output
          end
          .then do
            Mayu::Modules::Loaders::Transformers::Ruby.transform(
              _1,
              haml,
              component_base_class: "Mayu::Component::Base"
            )
          end

      if File.exist?(ruby)
        assert_equal(File.read(ruby), output)
      else
        puts "\e[33mWriting #{ruby}\e[0m"
        File.write(ruby, output)
      end
    end
  end
end
