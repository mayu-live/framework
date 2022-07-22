require "securerandom"

class Mayu::Server::Session
  attr_reader :id

  def initialize
    @id = SecureRandom.uuid
  end

  def handle_event(handler_id, payload = {})
    puts "#{handler_id} #{payload.inspect}"
  end
end
