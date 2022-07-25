module Mayu
  module Server
    module Types
      TRackHeaders = T.type_alias {
        T::Hash[String, String]
      }

      TRackReturn = T.type_alias {
        [
          Integer,
          TRackHeaders,
          T.any(T::Array[String], Async::HTTP::Body::Writable),
        ]
      }

      TRackApp = T.type_alias {
        T.proc
          .params(arg0: TRackHeaders)
          .returns([Integer, TRackHeaders, Array])
      }
    end
  end
end
