def append_part(str1, str2)
  return nil if str1.strip.empty? || str1.length >= str2.length

  equal_length = str1.chars.zip(str2.chars.slice(0, str1.length)).take_while { |c1, c2| c1 == c2}.length
  return nil if equal_length.zero?

  str2.slice(equal_length..-1)
end

p append_part("hej", "hejsan")
