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

      AddStyleSheet = PatchData.define(:filename)

      Transfer = PatchData.define(:payload)
      TransferFailed = PatchData.define()

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
        )

      ViewTransition = PatchData.define(:patches)

      Batch = PatchData.define(:patches)
    end
  end
end
