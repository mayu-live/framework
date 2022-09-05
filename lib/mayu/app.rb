# typed: strict

module Mayu
  module App
    extend T::Sig

    sig { params(name: Symbol, resources: T.nilable(Module)).void }
    def self.replace_module(name, **resources)
      mod = Module.new
      resources.each { |key, value| mod.const_set(key, value || Module.new) }
      remove_const(name) if const_defined?(name)
      const_set(name, mod)
    end
  end
end
