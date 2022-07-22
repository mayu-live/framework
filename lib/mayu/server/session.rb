# typed: strict

require "securerandom"

class Mayu::Server::Session
  extend T::Sig

  attr_reader :id

  def initialize
    @id = SecureRandom.uuid
  end

  sig {params(handler_id: String, payload: T.all).void}
  def handle_event(handler_id, payload = {})
    puts "#{handler_id} #{payload.inspect}"
  end
end
