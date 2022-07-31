module Mayu
  module Server
    module Types
      TRackHeaders = T.type_alias { T::Hash[String, String] }

      TRackReturn =
        T.type_alias do
          [
            Integer,
            TRackHeaders,
            T.any(T::Array[String], Async::HTTP::Body::Writable)
          ]
        end

      TRackApp =
        T.type_alias do
          T
            .proc
            .params(arg0: TRackHeaders)
            .returns([Integer, TRackHeaders, Array])
        end
    end
  end
end
