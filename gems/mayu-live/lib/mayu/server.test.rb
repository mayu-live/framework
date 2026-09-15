#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"

require_relative "server"

class Mayu::ServerTest < Minitest::Test
  def test_self_signed_cert_explains_the_missing_localhost_gem
    error =
      assert_raises(Mayu::Server::MissingLocalhostGemError) do
        without_gem("localhost") do
          Mayu::Server.self_signed_cert_ssl_context("localhost")
        end
      end

    assert_includes(error.message, "mayu-build")
    assert_includes(error.message, "self_signed_cert")
  end

  def test_other_load_errors_are_not_mistaken_for_the_missing_gem
    assert_raises(LoadError) do
      without_gem("openssl") do
        Mayu::Server.self_signed_cert_ssl_context("localhost")
      end
    end
  end

  private

  def without_gem(missing_feature, &)
    error = LoadError.new("cannot load such file -- #{missing_feature}")
    error.define_singleton_method(:path) { missing_feature }
    Mayu::Server.stub(:require, ->(_feature) { raise error }, &)
  end
end
