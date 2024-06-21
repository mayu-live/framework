# frozen_string_literal: true
#
# This module has been ported from ReactJS.
# https://github.com/facebook/react/blob/ec9400dc41715bb6ff0392d6320c33627fa7e2ba/packages/react-dom-bindings/src/client/validateDOMNesting.js
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module DOMNestingValidation
      # https://html.spec.whatwg.org/multipage/syntax.html#special
      SPECIAL_TAGS = %i[
        address
        applet
        area
        article
        aside
        base
        basefont
        bgsound
        blockquote
        body
        br
        button
        caption
        center
        col
        colgroup
        dd
        details
        dir
        div
        dl
        dt
        embed
        fieldset
        figcaption
        figure
        footer
        form
        frame
        frameset
        h1
        h2
        h3
        h4
        h5
        h6
        head
        header
        hgroup
        hr
        html
        iframe
        img
        input
        isindex
        li
        link
        listing
        main
        marquee
        menu
        menuitem
        meta
        nav
        noembed
        noframes
        noscript
        object
        ol
        p
        param
        plaintext
        pre
        script
        section
        select
        source
        style
        summary
        table
        tbody
        td
        template
        textarea
        tfoot
        th
        thead
        title
        tr
        track
        ul
        wbr
        xmp
      ].freeze

      # https://html.spec.whatwg.org/multipage/syntax.html#has-an-element-in-scope
      IN_SCOPE_TAGS = %i[
        applet
        caption
        html
        table
        td
        th
        marquee
        object
        template
        foreignObject
        desc
        title
      ].freeze

      # https://html.spec.whatwg.org/multipage/syntax.html#has-an-element-in-button-scope
      BUTTON_SCOPE_TAGS = [*IN_SCOPE_TAGS, :button].freeze

      # https://html.spec.whatwg.org/multipage/syntax.html#generate-implied-end-tags
      IMPLIED_END_TAGS = %i[dd dt li option optgroup p rp rt].freeze

      class AncestorInfo < Struct.new(
        :current,
        :form_tag,
        :a_tag_in_scope,
        :button_tag_in_scope,
        :nobr_tag_in_scope,
        :p_tag_in_button_scope,
        :list_item_tag_autoclosing,
        :dl_item_tag_autoclosing,
        :container_tag_in_scope
      )
        EMPTY = new(nil, nil, nil, nil, nil, nil, nil, nil, nil).freeze

        def update(tag)
          ancestor_info = dup

          if IN_SCOPE_TAGS.include?(tag)
            ancestor_info.a_tag_in_scope = nil
            ancestor_info.button_tag_in_scope = nil
            ancestor_info.nobr_tag_in_scope = nil
          end

          if BUTTON_SCOPE_TAGS.include?(tag)
            ancestor_info.p_tag_in_button_scope = nil
          end

          if SPECIAL_TAGS.include?(tag) && !(tag in :address | :div | :p)
            ancestor_info.list_item_tag_autoclosing = nil
            ancestor_info.dl_item_tag_autoclosing = nil
          end

          info = tag
          ancestor_info.current = info

          case tag
          in :form
            ancestor_info.form_tag = info
          in :a
            ancestor_info.a_tag_in_scope = info
          in :button
            ancestor_info.button_tag_in_scope = info
          in :nobr
            ancestor_info.nobr_tag_in_scope = info
          in :p
            ancestor_info.p_tag_in_button_scope = info
          in :li
            ancestor_info.list_item_tag_autoclosing = info
          in :dd | :dt
            ancestor_info.dl_item_tag_autoclosing = info
          in :html
            ancestor_info.container_tag_in_scope = nil
          else
            ancestor_info.container_tag_in_scope ||= info
          end

          ancestor_info
        end

        def find_invalid_ancestor_for_tag(tag)
          case tag
          in :address | :article | :aside | :blockquote | :center | :details |
               :dialog | :dir | :div | :dl | :fieldset | :figcaption | :figure |
               :footer | :header | :hgroup | :main | :menu | :nav | :ol | :p |
               :section | :summary | :ul | :pre | :listing | :table | :hr |
               :xmp | :h1 | :h2 | :h3 | :h4 | :h5 | :h6
            p_tag_in_button_scope
          in :form
            form_tag || p_tag_in_button_scope
          in :li
            list_item_tag_autoclosing
          in :dd | :dt
            dl_item_tag_autoclosing
          in :button
            button_tag_in_scope
          in :a
            a_tag_in_scope
          in :nobr
            nobr_tag_in_scope
          else
            nil
          end
        end
      end

      def self.validate(child_tag, ancestor_info = AncestorInfo::EMPTY)
        parent_tag = ancestor_info.current

        invalid_parent =
          valid_parent_child?(parent_tag, child_tag) ? nil : parent_tag
        invalid_ancestor =
          (
            if invalid_parent
              nil
            else
              ancestor_info.find_invalid_ancestor_for_tag(child_tag)
            end
          )

        invalid_parent_or_ancestor = invalid_parent || invalid_ancestor

        return nil unless invalid_parent_or_ancestor

        if invalid_parent
          info = ""

          if parent_tag == :table && child_tag == :tr
            info +=
              " Add a <tbody>, <thead> or <tfoot> to your code to match the browser."
          end

          format(
            "In HTML, <%s> can not be a child of <%s>.%s",
            child_tag,
            invalid_parent,
            info
          )
        else
          format(
            "In HTML, <%s> can not be a descendant of <%s>.",
            child_tag,
            invalid_ancestor
          )
        end
      end

      def self.valid_parent_child?(parent, child)
        case parent
        in :select
          return(child in :hr | :option | :optgroup)
        in :optgroup
          return(child in :option)
        in :tr
          return(child in :th | :td | :style | :script | :template)
        in :tbody | :thead | :tfoot
          return(child in :tr | :style | :script | :template)
        in :colgroup
          return(child in :col | :template)
        in :table
          return(
            child in
              :caption | :colgroup | :tbody | :tfoot | :thead | :style |
                :script | :template
          )
        in :head
          return(
            child in
              :base | :basefont | :bgsound | :link | :meta | :title |
                :noscript | :noframes | :style | :script | :template
          )
        in :html
          return(child in :__head | :body | :frameset)
        in :frameset
          return(child in :frame)
        else
          case child
          in :h1 | :h2 | :h3 | :h4 | :h5 | :h6
            return !(parent in :h1 | :h2 | :h3 | :h4 | :h5 | :h6)
          in :rp | :rt
            return !IMPLIED_END_TAGS.include?(parent)
          in :body | :caption | :col | :colgroup | :frameset | :frame | :html |
               :tbody | :td | :tfoot | :th | :thead | :tr
            return false
          else
            true
          end
        end
      end
    end
  end
end
