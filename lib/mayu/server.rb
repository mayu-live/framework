# typed: false
require 'sinatra/base'
require 'sinatra/cookies'
require 'securerandom'

require_relative "server/session"

class Mayu::Server
  SESSIONS = T.let([], T::Array[Mayu::Server::Session])

  helpers Sinatra::Cookies

  # Static files

  get "/favicon.ico" do
    content_type "image/jpeg"
    send_file "favicon.jpeg"
  end

  get "/__mayu/live.js" do
    content_type "application/javascript"
    send_file "client/dist/live.js"
  end

  # Server Sent Events endpoint

  get "/__mayu/live/:session_id" do
    "ok"
  end

  # Callback handlers

  post "/__mayu/callback/:session_id/:handler_id" do
    session = SESSIONS.fetch(params[:session_id]) {
      raise "Coult not find session with id: #{params[:session_id]}, has #{SESSIONS.keys.inspect}"
    }

    session.handle_event(params[:handler_id], params[:payload])

    "ok"
  end

  # Catch-all that creates a new session and sends the initial HTML

  get "/*" do
    session = Session.new
    puts request.fullpath

    SESSIONS[session.id] = session
    puts "Storing session #{session.id}"

    "<!doctype html>" + session.render
  end
end
