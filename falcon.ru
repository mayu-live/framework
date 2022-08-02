#!/usr/bin/env falcon --verbose serve -c
# frozen_string_literal: true

require "rack"
require "rack/utils"
require "cgi"
require "securerandom"

class Session
  class << self
    def __SESSIONS__
      $__mayu__sessions__ ||= {}
    end

    def fetch(id, &block)
      __SESSIONS__.fetch(id, &block)
    end

    def store(session)
      __SESSIONS__.store(session.id, session)
    end

    def delete(id)
      __SESSIONS__.delete(id)&.stop
    end
  end

  def self.init(task: Async::Task.current)
    self.store(new(task:))
  end

  def self.connect(id, key, task: Async::Task.current)
    self.fetch(id) { return :session_not_found }.connect(key, task:)
  end

  def self.cookie_name(id) = "mayu-session-#{id}"

  DEFAULT_TIMEOUT_IN_SECONDS = 3

  attr_reader :id
  attr_reader :key

  def initialize(timeout_in_seconds = DEFAULT_TIMEOUT_IN_SECONDS, task: Async::Task.current)
    @id = SecureRandom.uuid
    @key = SecureRandom.uuid
    @timeout_in_seconds = timeout_in_seconds
    @semaphore = Async::Semaphore.new(1)
    @messages = Async::Queue.new
    @task = task
    @timeout_task = nil

    @task.async do
      loop do
	push(:foo, Time.now.to_s)
	sleep 1
      end
    ensure
      puts "Stopping the message sending task"
    end

    start_timeout
  end

  def stop = @task.stop
  def cookie_name = self.class.cookie_name(id)

  def push(event, data = {})
    id = SecureRandom.uuid
    @messages.enqueue(format_message(id, event, data))
  end

  def connect(session_key, task: Async::Task.current)
    return :bad_session_key unless @key == session_key
    return :too_many_connections if @semaphore.blocking?

    body = Async::HTTP::Body::Writable.new

    @semaphore.async do
      puts "\e[31mStarting connection\e[0m"

      @timeout_task&.stop

      task.async do
	puts "Starting message pulling loop"
	loop do
	  message = @messages.dequeue
	  puts "Got message"
	  puts message.inspect
	  body.write(message.to_s + "\n")
	end
      ensure
	puts "\e[31mClosing connection\e[0m"
	body.close
	start_timeout
      end.wait

      puts "dequiring"
    end

    body
  end

  private

  def format_message(id, event, data)
    <<~MSG
      id: #{SecureRandom.uuid}
      event: #{event}
      data: #{JSON.generate(data)}
    MSG
  end

  def start_timeout
    return if @timeout_task

    @timeout_task = @task.async do |subtask|
      puts "\e[33mStarting timeout\e[0m"

      @timeout_in_seconds.downto(0) do |i|
	puts "\e[33mTimeout: #{i} seconds left\e[0m"
	subtask.sleep 1
      end

      puts "\e[31mDeleting the session\e[0m"

      self.class.delete(id)
    ensure
      puts "\e[33mClearing timeout\e[0m"
      @timeout_task = nil
    end
  end
end

class EventApp
  ENDPOINT_PATH = "/__mayu/events/"

  def call(env)
    request = Rack::Request.new(env)
    session_id = env[Rack::PATH_INFO].to_s.slice(1, 36).to_s
    cookie_name = Session.cookie_name(session_id)

    session_key = request.cookies.fetch(cookie_name) do
      #return [401, {}, ["Session cookie not set"]]
      "hej"
    end

    task = Async::Task.current

    case Session.connect(session_id, session_key, task:)
    in :session_not_found
      [404, {}, ["Session not found"]]
    in :bad_session_key
      [403, {}, ["Bad session key"]]
    in :too_many_connections
      [429, {}, ["Too many connections"]]
    in Async::HTTP::Body::Writable => body
      [200, { "content-type" => "text/event-stream; charset=utf-8" }, body]
    else
      [500, {}, ["Internal server error"]]
    end
  end
end

class SessionApp
  def call(env)
    session = Session.init

    response = Rack::Response.new("redirecting", 302)

    path = "#{EventApp::ENDPOINT_PATH}#{session.id}"

    response.set_cookie(session.cookie_name, {
      path:,
      secure: true,
      http_only: true,
      same_site: :strict,
      value: session.key,
    })

    response.set_header("location", path)

    response.finish
  end
end

run(Rack::Builder.new do
  map EventApp::ENDPOINT_PATH do
    run EventApp.new
  end

  run SessionApp.new
end)
