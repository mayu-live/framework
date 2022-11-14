puts "ICONS = {"

Dir["./*.svg"].each do |file|
  puts "  #{File.basename(file, ".svg").delete_suffix("-solid").inspect} => svg(#{file.inspect}),"
end

puts "}.freeze"
