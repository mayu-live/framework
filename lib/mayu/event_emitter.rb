# typed: strict

require "set"
require "async/queue"

module Mayu
  class EventEmitter
    extend T::Sig

    DEFAULT_MAX_LISTENERS = 10

    Listener =
      T.type_alias { T.any(OnceWrapper, T.proc.params(args: T.untyped).void) }

    class OnceWrapper
      extend T::Sig

      sig do
        params(emitter: EventEmitter, type: Symbol, listener: Listener).void
      end
      def initialize(emitter, type, listener)
        @emitter = emitter
        @type = type
        @listener = listener
        @fired = T.let(false, T::Boolean)
      end

      sig { params(args: T.untyped).void }
      def call(*args)
        return if @fired
        @emitter.off(@type, self)
        @fired = true
        T.unsafe(@listener).call(*args)
      end
    end

    sig { params(max_listeners: Integer).void }
    def initialize(max_listeners: DEFAULT_MAX_LISTENERS)
      @events = T.let({}, T::Hash[Symbol, T::Set[Listener]])
      @max_listeners = max_listeners
    end

    sig { params(type: Symbol, args: T.untyped).returns(self) }
    def emit(type, *args)
      @events[type]&.each { |listener| T.unsafe(listener).call(*args) }

      self
    end

    sig { params(type: Symbol, listener: Listener).returns(self) }
    def on(type, listener)
      events = @events[type] ||= Set.new
      events.add(listener)
      self
    end

    sig { params(type: Symbol, listener: Listener).returns(self) }
    def on(type, listener)
      events = @events[type] ||= Set.new
      wrapper = ->(*args) { listener.call(*args) }
      events.add(wrapper)
      self
    end

    sig { params(type: Symbol, listener: Listener).returns(self) }
    def off(type, listener)
      @events[type]&.delete(listener)
      @events.delete(type) if @events[type]&.empty?
      self
    end

    private

    sig { params(type: Symbol).void }
    def check_max_listeners(type)
      count = @events[type]&.size.to_i

      return if count < @max_listeners

      Console
        .logger
        .error(self) do
          "MaxListenersExceededWarning: Got #{count} listeners on #{type}"
        end
    end
  end
end
