# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

# DO NOT EDIT! Use script/create_patches.rb to regenerate

module Mayu
  module Runtime
    module Patches
      class PatchData < Data
        def to_msgpack(packer)
          packer.pack([self.class.name[/[^:]+\z/], *deconstruct])
        end
      end

      Initialize = PatchData.define(:id_tree)

      CreateTree = PatchData.define(:html, :tree)

      CreateElement = PatchData.define(:id, :type)
      CreateTextNode = PatchData.define(:id, :content)
      CreateComment = PatchData.define(:id, :content)

      ReplaceChildren = PatchData.define(:id, :child_ids)

      RemoveNode = PatchData.define(:id)

      SetAttribute = PatchData.define(:id, :name, :value)
      RemoveAttribute = PatchData.define(:id, :name)

      SetClassName = PatchData.define(:id, :class_name)
      AddClass = PatchData.define(:id, :classes)
      RemoveClass = PatchData.define(:id, :classes)

      SetListener = PatchData.define(:id, :name, :listener_id)
      RemoveListener = PatchData.define(:id, :name, :listener_id)

      SetCSSProperty = PatchData.define(:id, :name, :value)
      RemoveCSSProperty = PatchData.define(:id, :name)

      SetTextContent = PatchData.define(:id, :content)
      ReplaceData = PatchData.define(:id, :offset, :count, :data)
      InsertData = PatchData.define(:id, :offset, :data)
      DeleteData = PatchData.define(:id, :offset, :count)

      Transfer = PatchData.define(:payload)
      TransferFailed = PatchData.define

      Ping = PatchData.define(:timestamp)
      Pong = PatchData.define(:timestamp)

      Event = PatchData.define(:event, :payload)
      HistoryPushState = PatchData.define(:path)

      RegisterCustomElement = PatchData.define(:name, :path)

      RenderError =
        PatchData.define(
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
          # byte values. Error patches are entirely textual, so explicitly
          # serialize their strings as UTF-8 without changing binary payloads
          # used by other patch types.
          def to_msgpack(packer)
            packer.pack(
              [
                self.class.name[/[^:]+\z/],
                Patches.utf8(file),
                Patches.utf8(type),
                Patches.utf8(message),
                backtrace.map { Patches.utf8(it) },
                source && Patches.utf8(source),
                tree_path.map do |path|
                  path.transform_values do |value|
                    value.is_a?(String) ? Patches.utf8(value) : value
                  end
                end
              ]
            )
          end
        end

      def self.utf8(value)
        value.to_s.dup.force_encoding(Encoding::UTF_8).scrub
      end

      ViewTransition = PatchData.define(:patches)

      Batch = PatchData.define(:patches)
    end
  end
end
