require "json"

attributes = JSON.parse(File.read('html-element-attributes.json'))
global = attributes.delete("*")

puts "module HTMLTags"
attributes.each do |tag, attrs|
  all = (global + attrs).uniq
  sigs = all.map { "#{_1}: T.nilable(String)" }.join(", ")
  puts "  sig { params(children: Children, #{sigs}).returns(Descriptor) }"
  args = all.map { "#{_1}: nil" }.join(", ")
  puts "  def #{tag}(*children, #{args}, &block) = nil"
end
puts "end"
