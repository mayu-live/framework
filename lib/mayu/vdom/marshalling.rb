# typed: strict

module Mayu
  module VDOM
    module Marshalling
      extend T::Sig

      sig { params(vtree: VTree).returns(String) }
      def self.dump(vtree)
        Marshal.dump(vtree)
      end

      sig do
        params(dumped: String, session: Session, task: Async::Task).returns(
          VTree
        )
      end
      def self.restore(dumped, session:, task: Async::Task.current)
        vtree =
          Marshal.restore(
            dumped,
            ->(obj) do
              case obj
              when VDOM::VTree
                obj.instance_variable_set(:@session, session)
                obj.instance_variable_set(:@task, task)
                obj
              when VDOM::ComponentMarshaler
                case obj.type
                in klass:
                  klass
                in component:
                  T.cast(
                    session.environment.resources.load_resource(component).type,
                    Resources::Types::Component
                  ).component
                else
                  obj.type
                end
              else
                obj
              end
            end
          )

        vtree.root&.traverse do |vnode|
          vnode.instance_variable_set(:@vtree, vtree)
        end

        vtree
      end

      sig { params(props: Component::Props).returns(Component::Props) }
      def self.dump_props(props)
        props.transform_values { |value| dump_value(value) }
      end

      sig { params(state: Component::State).returns(Component::State) }
      def self.dump_state(state)
        state.transform_values { |value| dump_value(value) }
      end

      sig { params(value: T.untyped).returns(T.untyped) }
      def self.dump_value(value)
        case value
        when Hash
          value.transform_values { dump_value(_1) }
        when Array
          value.map { dump_value(_1) }
        when Component
          ComponentMarshaler.new(value)
        else
          value
        end
      end
    end
  end
end
