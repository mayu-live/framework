# typed: strict

module Mayu
  module DevServer
    module FakeNATS
      class Msg
        extend T::Sig

        sig { returns(String) }
        attr_reader :subject
        sig { returns(String) }
        attr_reader :data
        sig { returns(T.nilable(String)) }
        attr_reader :respond_to

        sig do
          params(
            client: FakeNATS::Client,
            subject: String,
            data: String,
            respond_to: T.nilable(String)
          ).void
        end
        def initialize(client, subject, data, respond_to: nil)
          @client = client
          @subject = subject
          @data = data
          @respond_to = respond_to
        end

        def respond(data)
          @client.publish(@respond_to, data)
        end
      end

      class Client
        extend T::Sig

        sig { void }
        def initialize
          @subscriptions = T.let({}, T::Hash[String, Async::Condition])
        end

        sig do
          params(
            subject: String,
            data: String,
            respond_to: T.nilable(String)
          ).void
        end
        def publish(subject, data, respond_to: nil)
          @subscriptions
            .fetch(subject) { raise NATS::IO::NoRespondersError }
            .signal(Msg.new(self, subject, data, respond_to:))
        end

        class Sub
          extend T::Sig

          sig { void }
          def unsubscribe
            throw :unsubscribe
          end
        end

        sig do
          params(
            subject: String,
            queue: T.nilable(String),
            task: Async::Task,
            block: T.proc.params(arg0: Msg).void
          ).returns(Sub)
        end
        def subscribe(subject, queue: nil, task: Async::Task.current, &block)
          subscription = @subscriptions[subject] ||= Async::Condition.new

          task.async do
            catch(:unsubscribe) { loop { yield subscription.wait } }
          end

          Sub.new
        end

        sig { params(subject: String, data: String).returns(Msg) }
        def request(subject, data)
          respond_to = SecureRandom.uuid
          condition = Async::Condition.new

          subscribe(respond_to) do |msg|
            condition.signal(msg)
            throw :unsubscribe
          end

          publish(subject, data, respond_to:)

          condition.wait
        end

        sig { params(servers: [String], kwargs: T.untyped).void }
        def connect(servers:, **kwargs)
          Console.logger.info(
            self,
            "Connecting to #{servers.inspect} #{kwargs.inspect}"
          )
        end

        sig { params(block: T.proc.void).void }
        def on_disconnect(&block)
        end

        sig { params(block: T.proc.void).void }
        def on_reconnect(&block)
        end
      end
    end
  end
end
