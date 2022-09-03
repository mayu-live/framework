# typed: strict

require_relative "module_types"

module Mayu
  module Modules2
    class Mod
      extend T::Sig

      sig { returns(String) }
      attr_reader :path
      sig { returns(ModuleTypes::Base) }
      attr_reader :type

      sig { params(system: System, path: String).void }
      def initialize(system, path)
        @system = system
        @path = path
        @assets = T.let({}, T::Hash[String, String])
        @extname = T.let(nil, T.nilable(String))
        @hash = T.let(nil, T.nilable(String))
        @type = T.let(ModuleTypes.load(self), ModuleTypes::Base)
      end

      sig { params(path: String).returns(Mod) }
      def load_relative(path)
        @system.load(path, File.dirname(path))
      end

      sig { returns(String) }
      def extname
        @extname ||= File.extname(@path)
      end

      sig { returns(String) }
      def hash
        @hash || recalculate_hash
      end

      sig { returns(String) }
      def recalculate_hash
        @hash = Digest::SHA256.digest(File.read(absolute_path))
      end

      sig { returns(String) }
      def absolute_path
        File.join(@system.root, path)
      end

      sig { params(system: System, path: String).returns(T.attached_class) }
      def self.load(system, path)
        new(system, path)
      end
    end
  end
end
