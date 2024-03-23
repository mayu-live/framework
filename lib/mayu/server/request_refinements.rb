module Mayu
  class Server
    module RequestRefinements
      refine Async::HTTP::Protocol::HTTP2::Request do
        def deconstruct_keys(keys)
          keys.each_with_object({}) do |key, obj|
            var = "@#{key}"

            if instance_variable_defined?(var)
              obj[key] = instance_variable_get(var)
            end
          end
        end
      end
    end
  end
end
