# typed: strict

require "securerandom"

class Mayu::Server::Session
  extend T::Sig

  sig {returns(String)}
  attr_reader :id

  sig {void}
  def initialize
    @id = T.let(SecureRandom.uuid, String)
  end

  sig {params(handler_id: String, payload: T.untyped).void}
  def handle_event(handler_id, payload = {})
    puts "#{handler_id} #{payload.inspect}"
  end
end
