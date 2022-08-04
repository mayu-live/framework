# typed: strict

module Mayu
  module App
    extend T::Sig

    sig {params(name: Symbol, modules: T.nilable(Module)).void}
    def self.replace_module(name, **modules)
      mod = Module.new
      modules.each do |key, value|
        mod.const_set(key, value || Module.new)
      end
      remove_const(name) if const_defined?(name)
      const_set(name, mod)
    end
  end
end
