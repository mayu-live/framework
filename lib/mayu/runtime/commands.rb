# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    Batch =
      Data.define(:commands, :completion) do
        def self.[](commands, completion: nil)
          unless commands.is_a?(Array)
            raise ArgumentError, "Batch commands must be an array"
          end

          new(commands: commands.dup.freeze, completion:)
        end

        def validate!
          unless commands.is_a?(Array) && commands.all? { |command|
                   command.is_a?(Commands::CommandData)
                 }
            raise ArgumentError, "Batch entries must be runtime commands"
          end

          self
        end

        def terminal?
          commands.any? do |command|
            command.is_a?(Commands::Transfer) ||
              command.is_a?(Commands::TransferFailed)
          end
        end

        def empty?
          commands.empty?
        end

        def complete
          completion&.enqueue(true)
        end

        def to_msgpack(packer)
          validate!
          packer.pack(commands)
        end
      end

    module Commands
      class CommandData < Data
        def to_msgpack(packer)
          packer.pack([self.class.name[/[^:]+\z/], *deconstruct])
        end
      end

      Initialize = CommandData.define(:id_tree)

      CreateTree = CommandData.define(:html, :tree)

      CreateElement = CommandData.define(:id, :type)
      CreateTextNode = CommandData.define(:id, :content)
      CreateComment = CommandData.define(:id, :content)

      ReplaceChildren = CommandData.define(:id, :child_ids)

      RemoveNode = CommandData.define(:id)

      SetAttribute = CommandData.define(:id, :name, :value)
      RemoveAttribute = CommandData.define(:id, :name)

      SetClassName = CommandData.define(:id, :class_name)
      AddClass = CommandData.define(:id, :classes)
      RemoveClass = CommandData.define(:id, :classes)

      SetListener = CommandData.define(:id, :name, :listener_id)
      RemoveListener = CommandData.define(:id, :name, :listener_id)

      SetCSSProperty = CommandData.define(:id, :name, :value)
      RemoveCSSProperty = CommandData.define(:id, :name)

      SetTextContent = CommandData.define(:id, :content)
      ReplaceData = CommandData.define(:id, :offset, :count, :data)
      InsertData = CommandData.define(:id, :offset, :data)
      DeleteData = CommandData.define(:id, :offset, :count)

      Transfer = CommandData.define(:payload)
      TransferFailed = CommandData.define

      Pong = CommandData.define(:timestamp)

      ReloadSucceeded = CommandData.define
      HistoryPushState = CommandData.define(:path)

      RegisterCustomElement = CommandData.define(:name, :path)

      RenderError =
        CommandData.define(
          :file,
          :type,
          :message,
          :backtrace,
          :source,
          :tree_path
        ) do
          # Ruby MessagePack serializes ASCII-8BIT strings as binary values.
          # The browser decoder represents those values as Uint8Array, which
          # makes an error such as a Haml parse error render as comma-separated
          # byte values. Error commands are entirely textual, so explicitly
          # serialize their strings as UTF-8 without changing binary payloads
          # used by other command types.
          def to_msgpack(packer)
            packer.pack(
              [
                self.class.name[/[^:]+\z/],
                Commands.utf8(file),
                Commands.utf8(type),
                Commands.utf8(message),
                backtrace.map { Commands.utf8(it) },
                source && Commands.utf8(source),
                tree_path.map do |path|
                  path.transform_values do |value|
                    value.is_a?(String) ? Commands.utf8(value) : value
                  end
                end
              ]
            )
          end
        end

      ANSI_ESCAPE = /\e\[[0-9;]*m/

      # Build errors format their source excerpts for a terminal, and the
      # browser would show the escape sequences verbatim.
      def self.utf8(value)
        value.to_s.dup.force_encoding(Encoding::UTF_8).scrub.gsub(
          ANSI_ESCAPE,
          ""
        )
      end

      ViewTransition = CommandData.define(:batch)
    end
  end
end
