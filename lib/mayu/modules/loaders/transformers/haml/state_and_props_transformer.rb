# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../mutation_visitor"

module Mayu
  module Modules
    module Loaders
      module Transformers
        module Haml
          class StateAndPropsTransformer
            include SyntaxTree::DSL

            def initialize(provides_context = Set.new)
              @provides_context = provides_context
            end

            def visitor
              MutationVisitor.build do |visitor|
                visitor.mutate(
                  "VarRef[value: GVar[value: /\\A\\$\\*/]]"
                ) { |var_ref| props_ivar }

                visitor.mutate(
                  "VarRef[value: GVar[value: /\\A\\$[\\w_]+/]]"
                ) { |var_ref| props_aref(var_ref.value) }

                visitor.mutate(
                  "Assign[target: VarField[value: GVar]]"
                ) do |assign|
                  assign => { target: { target: { value: var_name } } }
                  loc = assign.target.location
                  raise "Can not write to prop #{var_name} on line #{loc.start_line} col #{loc.start_column}"
                end

                visitor.mutate("VarRef[value: CVar]") do |node|
                  name = node.value.value.delete_prefix("@@")

                  ARef(VarRef(IVar("@__context")), SymbolLiteral(Ident(name)))
                end

                visitor.mutate(
                  "Assign[target: VarField[value: CVar]]"
                ) do |node|
                  name = node.target.value.value.delete_prefix("@@")
                  puts "ADDING #{name}"
                  @provides_context.add(name)
                  pp @provides_context

                  node.copy(
                    target:
                      ARef(
                        VarRef(IVar("@__context")),
                        SymbolLiteral(Ident(name))
                      )
                  )
                end

                visitor.mutate(
                  "OpAssign[target: VarField[value: CVar]]"
                ) do |node|
                  name = node.target.value.value.delete_prefix("@@")
                  @provides_context.add(name)

                  node.copy(
                    target:
                      ARef(
                        VarRef(IVar("@__context")),
                        SymbolLiteral(Ident(name))
                      )
                  )
                end

                visitor.mutate(
                  "OpAssign[target: VarField[value: IVar]]"
                ) do |assign|
                  CallNode(nil, nil, Ident("update!"), ArgParen(Args([assign])))
                end

                visitor.mutate(
                  "Assign[target: VarField[value: IVar]]"
                ) do |assign|
                  CallNode(nil, nil, Ident("update!"), ArgParen(Args([assign])))
                end
              end
            end

            private

            def props_ivar
              VarRef(IVar("@__props"))
            end

            def props_aref(node)
              ARef(props_ivar, Args([var_to_symbol(node)]))
            end

            def call_self(method)
              CallNode(VarRef(Kw("self")), Period("."), Ident(method), nil)
            end

            def var_to_symbol(node)
              SymbolLiteral(Ident(strip_var_prefix(node.value)))
            end

            def strip_var_prefix(str)
              str[/\A[@$]*(.*)/, 1]
            end
          end
        end
      end
    end
  end
end
