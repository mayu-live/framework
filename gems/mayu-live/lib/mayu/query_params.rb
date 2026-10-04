# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "uri"

module Mayu
  class QueryParams < Hash
    def self.parse(query)
      new(URI.decode_www_form(query.to_s).to_h)
    end

    def initialize(values = {})
      super()
      values.each_pair { |key, value| self[key] = value }
    end

    def [](key) = super(normalize_key(key))

    def []=(key, value)
      super(normalize_key(key), value)
    end
    alias_method :store, :[]=

    def fetch(key, *defaults, &block)
      super(normalize_key(key), *defaults, &block)
    end

    def key?(key) = super(normalize_key(key))
    alias_method :has_key?, :key?
    alias_method :include?, :key?
    alias_method :member?, :key?

    def dig(key, *rest) = super(normalize_key(key), *rest)

    def values_at(*keys) = super(*keys.map { normalize_key(it) })

    def fetch_values(*keys, &block)
      super(*keys.map { normalize_key(it) }, &block)
    end

    def transform_values(&block)
      return to_enum(:transform_values) unless block

      self.class.new(super)
    end

    private

    def normalize_key(key)
      key.is_a?(Symbol) ? key.to_s : key
    end
  end
end
