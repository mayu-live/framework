# typed: strict

module Mayu
  module VDOM
    module Hydration
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
                  session.environment.modules.load_component(component)
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
    end
  end
end
