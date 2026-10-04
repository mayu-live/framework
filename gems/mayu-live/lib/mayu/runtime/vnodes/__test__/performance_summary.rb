#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

results = ARGV.map { JSON.parse(File.read(it), symbolize_names: true) }

puts "| Workload | Iterations | Warmup | CPU ms/update |"
puts "| --- | ---: | ---: | ---: |"
results.each do |result|
  puts format(
    "| %s | %d | %d | %.3f |",
    result.fetch(:workload),
    result.fetch(:iterations),
    result.fetch(:warmup),
    result.fetch(:cpu_ms_per_update)
  )
end
