# typed: strict

require "optparse"

case ARGV.first
when "serve"
  puts "TODO: Start server"
else
  puts "Invalid command: #{ARGV.first}"
  exit 1
end
