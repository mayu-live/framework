# typed: strict

module Mayu
  module VDOM
    class Indexes
      extend T::Sig
      extend T::Generic

      Elem = type_member

      sig { params(indexes: T::Array[Elem]).void }
      def initialize(indexes = [])
        @indexes = indexes
      end

      sig { params(id: Elem).void }
      def append(id)
        @indexes.delete(id)
        @indexes.push(id)
      end

      sig { params(index: Integer).returns(T.nilable(Elem)) }
      def [](index) = @indexes[index]

      sig { params(id: Elem).returns(T.nilable(Integer)) }
      def index(id) = @indexes.index(id)
      sig { params(id: Elem).returns(T.nilable(Integer)) }
      def rindex(id) = @indexes.rindex(id)

      sig { params(id: Elem, after: T.nilable(Elem)).void }
      def insert_after(id, after)
        insert_before(id, after && next_sibling(after))
      end

      sig { params(id: Elem, before: T.nilable(Elem)).void }
      def insert_before(id, before)
        @indexes.delete(id)
        index = before && @indexes.index(before)
        index ? @indexes.insert(index, id) : @indexes.push(id)
      end

      sig { params(id: Elem).returns(T.nilable(Elem)) }
      def next_sibling(id)
        if index = @indexes.index(id)
          @indexes[index.succ]
        end
      end

      sig { params(id: Elem).void }
      def remove(id) = @indexes.delete(id)

      sig { returns(T::Array[Elem]) }
      def to_a = @indexes
    end
  end
end
