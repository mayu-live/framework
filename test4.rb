# typed: false

require "bundler"
require "async"
require "async/barrier"
require "async/semaphore"
require "pry"
require "sorbet-runtime"

Async do
  barrier = Async::Barrier.new
  semaphore = Async::Semaphore.new(2)

  semaphore.async(parent: barrier) do
    s = "ggg"
    c = 5
    c.times do |i|
      sleep 1.0 / c
      puts "#{s}#{i}"
    end
  end

  semaphore.async(parent: barrier) do
    s = "lol"
    c = 5
    c.times do |i|
      sleep 1.0 / c
      puts "#{s}#{i}"
    end
  end

  semaphore.async(parent: barrier) do
    s = "asd"
    c = 10
    c.times do |i|
      sleep 1.0 / c
      puts "#{s}#{i}"
    end
  end

  puts "asd"
  sleep 0.2
  puts "xxxxxxxxxxxx"
  barrier.stop
end
