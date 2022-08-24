# typed: strict

module Mayu
  module Server
    class Config < T::Struct
      const :SECRET_KEY, String
      const :MAX_SESSIONS, Integer
      const :PRINT_CAPACITY_INTERVAL, Float
      const :HEARTBEAT_INTERVAL_SECONDS, Float
      const :KEEPALIVE_SECONDS, Float

      const :NATS_SERVER, String

      const :FLY_APP_NAME, String
      const :FLY_ALLOC_ID, String
      const :FLY_REGION, String
    end
  end
end
