# frozen_string_literal: true

source "https://rubygems.org"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "vendor", "patches"))

gem "pry"

gem "rake"
gem "rux"
gem "crass"
gem "falcon"
gem "toml-rb"
gem "prometheus-client"

gem "sorbet-runtime"
gem "async-http"
gem "filewatcher"
gem "nanoid"

group :development do
  gem "guard", require: false
  gem "guard-falcon", require: false
  gem "sorbet", require: false
  gem "tapioca", require: false
  gem "prettier", require: false
  gem "rack-test", require: false
  gem "minitest", require: false
  gem "rexml", require: false
  gem "minitest-reporters", require: false
end
