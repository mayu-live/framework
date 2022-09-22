# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `traces` gem.
# Please instead update this file by running `bin/tapioca gem traces`.

# source://traces-0.6.1/lib/traces/backend.rb:23
module Traces
  class << self
    # Extend the specified class in order to emit traces.
    #
    # source://traces-0.6.1/lib/traces/provider.rb:52
    def Provider(klass, &block); end

    # @return [Boolean]
    #
    # source://traces-0.6.1/lib/traces/provider.rb:27
    def enabled?; end

    # Require a specific trace backend.
    #
    # source://traces-0.6.1/lib/traces/backend.rb:25
    def require_backend(env = T.unsafe(nil)); end
  end
end

# A module which contains tracing specific wrappers.
#
# source://traces-0.6.1/lib/traces/provider.rb:32
module Traces::Provider
  # source://traces-0.6.1/lib/traces/provider.rb:33
  def traces_provider; end
end