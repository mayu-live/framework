# typed: strict

module Mayu
  module Server
    class Config < T::Struct
      const :SECRET_KEY, String
      const :MAX_SESSIONS, Integer
      const :PRINT_CAPACITY_INTERVAL, Float
      const :HEARTBEAT_INTERVAL_SECONDS, Float
      const :KEEPALIVE_SECONDS, Float
    end
  end
end
