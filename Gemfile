# frozen_string_literal: true

source "https://rubygems.org"

gemspec

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "vendor", "patches"))

group :development do
  gem "guard", require: false
  gem "localhost", require: false
  gem "minitest", require: false
  gem "minitest-reporters", require: false
  gem "prettier", require: false
  gem "rexml", require: false
  gem "ruby-prof", require: false
  gem "nokogiri", require: false
  gem "benchmark", require: false
end

gem "fuzzy_match"

gem "reline", "~> 0.4.2"
