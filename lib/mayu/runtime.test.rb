#!/usr/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require_relative "./test"

class Mayu::Runtime::Test < Minitest::Test
  H = Mayu::Runtime::H
  include Mayu::Test::Helpers

  class Counter < Mayu::Component::Base
    def initialize
      @count = 0
    end

    def handle_increment
      update!(@count += 1)
    end

    def render
      H[
        :section,
        H[:output, @count],
        H[:button, "Increment", onclick: H.callback(self, :handle_increment)],
        (H[:p, "Count is over 3", key: :over] if @count > 3),
        (H[:p, "Count is below 7", key: :below] if @count < 7)
      ]
    end
  end

  class Inputs < Mayu::Component::Base
    def initialize
      @value = ""
    end

    def handle_input(e)
      update!(@value = e.dig(:currentTarget, :value).to_s)
    end

    def render
      H[
        :fieldset,
        H[:legend, "Inputs"],
        H[:input, name: "hello", oninput: H.callback(self, :handle_input)],
        H[:output, @value.reverse.inspect]
      ]
    end
  end

  def test_engine
    descriptor =
      H[
        :body,
        H[:header, H[:h1, "My webpage"]],
        H[
          :main,
          H[:h2, "Welcome"],
          H[:p, "Welcome to my webpage"],
          H[Counter],
          H[Inputs]
        ],
        H[:footer, H[:p, "Copyright"]]
      ]

    render(descriptor) do |page|
      input = find!("input", name: "hello")

      input.type_input("hello world".reverse) do
        # page.step
      end

      button = find!("button", text: "Increment")

      10.times do
        button.click
        sleep 0.05
      end

      assert_equal("10", find!("output").content)
    end
  end

  class TitleThing < Mayu::Component::Base
    def initialize
      @enabled = false
    end

    def handle_toggle
      puts "\e[3;34mTOGGLING\e[0m"
      update!(@enabled = !@enabled)
    end

    def render
      puts "\e[3;34mRENDERING\e[0m"

      [
        (H[:head,
          H[:title, "TitleThing"],
          H[:meta, name: "description", value: "title thing description"],
          H[:meta, name: "keywords", value: "title, thing, titlething"],
        ] if @enabled),
        (H[:p, "Enabled: #{@enabled.inspect}"]),
        H[:button, "Toggle", onclick: H.callback(self, :handle_toggle)]
      ]
    end
  end

  def test_head
    descriptor =
      H[
        :body,
        H[
          :head,
          H[:title, "initial title"],
          H[:meta, name: "description", value: "initial description"],
        ],
        H[
          :main,
          H[:p, "hello world"],
          H[TitleThing]
        ],
      ]

    render(descriptor) do |page|
      # enable_step!

      assert_equal("initial title", find!("title").content)
      assert_equal("initial description", find!("meta", name: "description")[:value])
      assert_nil(find("meta", name: "keywords"))

      button = find!("button")

      button.click
      page.step

      assert_equal("TitleThing", find!("title").content)
      assert_equal("title thing description", find!("meta", name: "description")[:value])
      assert_equal("title, thing, titlething", find!("meta", name: "keywords")[:value])

      button.click
      page.step

      assert_equal("initial title", find!("title").content)
      assert_equal("initial description", find!("meta", name: "description")[:value])
      assert_nil(find("meta", name: "keywords"))
      page.step
    end
  end
end
