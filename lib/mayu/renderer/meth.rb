class Foo
  def handle_lol(*args)
    p args
  end

  def get_handler(name)
    method(:"handle_#{name}")
  end
end

require "pry"
lol = Foo.new.get_handler(:lol)
p lol
binding.pry
lol.call('asd')
