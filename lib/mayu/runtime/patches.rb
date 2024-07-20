# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

# DO NOT EDIT! Use script/create_patches.rb to regenerate

module Mayu
  module Runtime
    module Patches
      Initialize = Data.define(:id_tree)

      CreateTree = Data.define(:html, :tree)

      CreateElement = Data.define(:id, :type)
      CreateTextNode = Data.define(:id, :content)
      CreateComment = Data.define(:id, :content)

      ReplaceChildren = Data.define(:id, :child_ids)

      RemoveNode = Data.define(:id)

      SetAttribute = Data.define(:id, :name, :value)
      RemoveAttribute = Data.define(:id, :name)

      SetClassName = Data.define(:id, :class_name)
      AddClass = Data.define(:id, :classes)
      RemoveClass = Data.define(:id, :classes)

      SetListener = Data.define(:id, :name, :listener_id)
      RemoveListener = Data.define(:id, :name, :listener_id)

      SetCSSProperty = Data.define(:id, :name, :value)
      RemoveCSSProperty = Data.define(:id, :name)

      SetTextContent = Data.define(:id, :content)
      ReplaceData = Data.define(:id, :offset, :count, :data)
      InsertData = Data.define(:id, :offset, :data)
      DeleteData = Data.define(:id, :offset, :count)

      AddStyleSheet = Data.define(:filename)

      Transfer = Data.define(:payload)

      Ping = Data.define(:timestamp)
      Pong = Data.define(:timestamp)

      Event = Data.define(:event, :payload)
      HistoryPushState = Data.define(:path)

      RegisterCustomElement = Data.define(:name, :path)

      RenderError =
        Data.define(:file, :type, :message, :backtrace, :source, :tree_path)
    end
  end
end
