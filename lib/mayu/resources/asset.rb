# frozen_string_literal: true
# typed: strict

require_relative "generators/image"
require_relative "generators/copy_file"
require_relative "generators/write_file"

module Mayu
  module Resources
    class Asset
      extend T::Sig

      class Status < T::Enum
        enums do
          Pending = new
          Processing = new
          Done = new
          Failed = new
        end
      end

      sig { returns(String) }
      attr_reader :filename
      sig { returns(Status) }
      attr_reader :status
      sig { returns(Generators::Base) }
      attr_reader :generator

      sig { params(filename: String, generator: Generators::Base).void }
      def initialize(filename, generator)
        @filename = filename
        @generator = generator
        @status = T.let(Status::Pending, Status)
      end

      sig { returns(T::Boolean) }
      def pending? = @status == Status::Pending
      sig { returns(T::Boolean) }
      def processing? = @status == Status::Processing
      sig { returns(T::Boolean) }
      def done? = @status == Status::Done
      sig { returns(T::Boolean) }
      def failed? = @status == Status::Failed

      sig { params(asset_dir: String).returns(T::Boolean) }
      def process(asset_dir)
        return false unless pending?
        @status = Status::Processing
        @generator.process(File.join(asset_dir, filename))
      rescue StandardError
        @status = Status::Failed
        raise
      else
        @status = Status::Done
        true
      end

      MarshalFormat = T.type_alias { [String] }

      sig { returns(MarshalFormat) }
      def marshal_dump
        [@filename]
      end

      sig { params(args: MarshalFormat).void }
      def marshal_load(args)
        @filename = args.first
      end
    end
  end
end
