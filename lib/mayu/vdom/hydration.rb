# typed: strict

module Mayu
  module VDOM
    module Hydration
      extend T::Sig

      sig { params(vtree: VTree).returns(String) }
      def self.hydrate(vtree)
        Marshal.dump(vtree)
      end

      sig do
        params(
          hydrated: String,
          session: Server::Session,
          barrier: Async::Barrier
        ).returns(VTree)
      end
      def self.dehydrate(hydrated, session:, barrier:)
        Marshal.restore(
          hydrated,
          ->(obj) do
            case obj
            when VDOM::VTree
              obj.instance_variable_set(:@session, session)
              obj.instance_variable_set(:@task, barrier)
              obj
            when VDOM::Descriptor::ComponentMarshaler
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
      end
    end
  end
end
