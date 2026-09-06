# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Use the sibling Klenod checkout while the breaking migration is coordinated.
gem "klenod-build", path: "../../klenod/gems/klenod-build"
gem "klenod-runtime", path: "../../klenod/gems/klenod-runtime"
gem "klenod-rack", path: "../../klenod/gems/klenod-rack"
gem "klenod-plugin-css", path: "../../klenod/gems/klenod-plugin-css"
gem "klenod-plugin-javascript", path: "../../klenod/gems/klenod-plugin-javascript"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "vendor", "patches"))

group :development do
  gem "guard", require: false
  gem "localhost", require: false
  gem "minitest", require: false
  gem "minitest-mock", require: false
  gem "minitest-reporters", require: false
  gem "minitest-focus", require: false
  gem "prettier", require: false
  gem "rexml", require: false
  gem "ruby-prof", require: false
  gem "benchmark", require: false
  gem "vernier", require: false
  gem "irb", require: false

  gem "readline", require: false
  gem "reline", require: false
end
