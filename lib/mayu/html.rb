# typed: strict

module Mayu
  module HTML
    extend T::Sig

    # Source:
    # https://raw.githubusercontent.com/sindresorhus/html-tags/ff16c695dcf77e1973d17941c36af6ceda4bda10/html-tags-void.json
    VOID_TAGS =
      T.let(
        %i[
          area
          base
          br
          col
          embed
          hr
          img
          input
          link
          menuitem
          meta
          param
          source
          track
          wbr
        ].freeze,
        T::Array[Symbol]
      )

    # Source:
    # https://raw.githubusercontent.com/sindresorhus/html-tags/ff16c695dcf77e1973d17941c36af6ceda4bda10/html-tags.json
    TAGS =
      T.let(
        (
          %i[
            a
            abbr
            address
            area
            article
            aside
            audio
            b
            base
            bdi
            bdo
            blockquote
            body
            br
            button
            canvas
            caption
            cite
            code
            col
            colgroup
            data
            datalist
            dd
            del
            details
            dfn
            dialog
            div
            dl
            dt
            em
            embed
            fieldset
            figcaption
            figure
            footer
            form
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
            i
            iframe
            img
            input
            ins
            kbd
            label
            legend
            li
            link
            main
            map
            mark
            math
            menu
            menuitem
            meta
            meter
            nav
            noscript
            object
            ol
            optgroup
            option
            output
            p
            param
            picture
            pre
            progress
            q
            rb
            rp
            rt
            rtc
            ruby
            s
            samp
            script
            section
            select
            slot
            small
            source
            span
            strong
            style
            sub
            summary
            sup
            svg
            table
            tbody
            td
            template
            textarea
            tfoot
            th
            thead
            time
            title
            tr
            track
            u
            ul
            var
            video
            wbr
          ] + VOID_TAGS
        ).freeze,
        T::Array[Symbol]
      )

    # Source:
    # https://raw.githubusercontent.com/wooorm/html-element-attributes/270d8cec96afc251e1501ea5b8e16ad52b8bf875/index.js
    GLOBAL_ATTRIBUTES =
      T.let(
        %i[
          accesskey
          autocapitalize
          autofocus
          class
          contenteditable
          dir
          draggable
          enterkeyhint
          hidden
          id
          inputmode
          is
          itemid
          itemprop
          itemref
          itemscope
          itemtype
          lang
          nonce
          slot
          spellcheck
          style
          tabindex
          title
          translate
        ].freeze,
        T::Array[Symbol]
      )

    # Source:
    # https://raw.githubusercontent.com/wooorm/html-event-attributes/b6ee29864ca378f5084980445abed418ef0f1ab9/index.js
    EVENT_HANDLER_ATTRIBUTES = T.let(%i[
      onabort
      onafterprint
      onauxclick
      onbeforeprint
      onbeforeunload
      onblur
      oncancel
      oncanplay
      oncanplaythrough
      onchange
      onclick
      onclose
      oncontextlost
      oncontextmenu
      oncontextrestored
      oncopy
      oncuechange
      oncut
      ondblclick
      ondrag
      ondragend
      ondragenter
      ondragleave
      ondragover
      ondragstart
      ondrop
      ondurationchange
      onemptied
      onended
      onerror
      onfocus
      onformdata
      onhashchange
      oninput
      oninvalid
      onkeydown
      onkeypress
      onkeyup
      onlanguagechange
      onload
      onloadeddata
      onloadedmetadata
      onloadstart
      onmessage
      onmessageerror
      onmousedown
      onmouseenter
      onmouseleave
      onmousemove
      onmouseout
      onmouseover
      onmouseup
      onoffline
      ononline
      onpagehide
      onpageshow
      onpaste
      onpause
      onplay
      onplaying
      onpopstate
      onprogress
      onratechange
      onrejectionhandled
      onreset
      onresize
      onscroll
      onsecuritypolicyviolation
      onseeked
      onseeking
      onselect
      onslotchange
      onstalled
      onstorage
      onsubmit
      onsuspend
      ontimeupdate
      ontoggle
      onunhandledrejection
      onunload
      onvolumechange
      onwaiting
      onwheel
    ].freeze, T::Array[Symbol])

    # Source:
    # https://raw.githubusercontent.com/wooorm/html-element-attributes/270d8cec96afc251e1501ea5b8e16ad52b8bf875/index.js
    ATTRIBUTES =
      T.let(
        {
          a: %i[
            charset
            coords
            download
            href
            hreflang
            name
            ping
            referrerpolicy
            rel
            rev
            shape
            target
            type
          ],
          applet: %i[
            align
            alt
            archive
            code
            codebase
            height
            hspace
            name
            object
            vspace
            width
          ],
          area: %i[
            alt
            coords
            download
            href
            hreflang
            nohref
            ping
            referrerpolicy
            rel
            shape
            target
            type
          ],
          audio: %i[autoplay controls crossorigin loop muted preload src],
          base: %i[href target],
          basefont: %i[color face size],
          blockquote: [:cite],
          body: %i[alink background bgcolor link text vlink],
          br: [:clear],
          button: %i[
            disabled
            form
            formaction
            formenctype
            formmethod
            formnovalidate
            formtarget
            name
            type
            value
          ],
          canvas: %i[height width],
          caption: [:align],
          col: %i[align char charoff span valign width],
          colgroup: %i[align char charoff span valign width],
          data: [:value],
          del: %i[cite datetime],
          details: [:open],
          dialog: [:open],
          dir: [:compact],
          div: [:align],
          dl: [:compact],
          embed: %i[height src type width],
          fieldset: %i[disabled form name],
          font: %i[color face size],
          form: [
            :accept,
            :"accept-charset",
            :action,
            :autocomplete,
            :enctype,
            :method,
            :name,
            :novalidate,
            :target
          ],
          frame: %i[
            frameborder
            longdesc
            marginheight
            marginwidth
            name
            noresize
            scrolling
            src
          ],
          frameset: %i[cols rows],
          h1: [:align],
          h2: [:align],
          h3: [:align],
          h4: [:align],
          h5: [:align],
          h6: [:align],
          head: [:profile],
          hr: %i[align noshade size width],
          html: %i[manifest version],
          iframe: %i[
            align
            allow
            allowfullscreen
            allowpaymentrequest
            allowusermedia
            frameborder
            height
            loading
            longdesc
            marginheight
            marginwidth
            name
            referrerpolicy
            sandbox
            scrolling
            src
            srcdoc
            width
          ],
          img: %i[
            align
            alt
            border
            crossorigin
            decoding
            height
            hspace
            ismap
            loading
            longdesc
            name
            referrerpolicy
            sizes
            src
            srcset
            usemap
            vspace
            width
          ],
          input: %i[
            accept
            align
            alt
            autocomplete
            checked
            dirname
            disabled
            form
            formaction
            formenctype
            formmethod
            formnovalidate
            formtarget
            height
            ismap
            list
            max
            maxlength
            min
            minlength
            multiple
            name
            pattern
            placeholder
            readonly
            required
            size
            src
            step
            type
            usemap
            value
            width
          ],
          ins: %i[cite datetime],
          isindex: [:prompt],
          label: %i[for form],
          legend: [:align],
          li: %i[type value],
          link: %i[
            as
            charset
            color
            crossorigin
            disabled
            href
            hreflang
            imagesizes
            imagesrcset
            integrity
            media
            referrerpolicy
            rel
            rev
            sizes
            target
            type
          ],
          map: [:name],
          menu: [:compact],
          meta: [:charset, :content, :"http-equiv", :media, :name, :scheme],
          meter: %i[high low max min optimum value],
          object: %i[
            align
            archive
            border
            classid
            codebase
            codetype
            data
            declare
            form
            height
            hspace
            name
            standby
            type
            typemustmatch
            usemap
            vspace
            width
          ],
          ol: %i[compact reversed start type],
          optgroup: %i[disabled label],
          option: %i[disabled label selected value],
          output: %i[for form name],
          p: [:align],
          param: %i[name type value valuetype],
          pre: [:width],
          progress: %i[max value],
          q: [:cite],
          script: %i[
            async
            charset
            crossorigin
            defer
            integrity
            language
            nomodule
            referrerpolicy
            src
            type
          ],
          select: %i[autocomplete disabled form multiple name required size],
          slot: [:name],
          source: %i[height media sizes src srcset type width],
          style: %i[media type],
          table: %i[
            align
            bgcolor
            border
            cellpadding
            cellspacing
            frame
            rules
            summary
            width
          ],
          tbody: %i[align char charoff valign],
          td: %i[
            abbr
            align
            axis
            bgcolor
            char
            charoff
            colspan
            headers
            height
            nowrap
            rowspan
            scope
            valign
            width
          ],
          textarea: %i[
            autocomplete
            cols
            dirname
            disabled
            form
            maxlength
            minlength
            name
            placeholder
            readonly
            required
            rows
            wrap
          ],
          tfoot: %i[align char charoff valign],
          th: %i[
            abbr
            align
            axis
            bgcolor
            char
            charoff
            colspan
            headers
            height
            nowrap
            rowspan
            scope
            valign
            width
          ],
          thead: %i[align char charoff valign],
          time: [:datetime],
          tr: %i[align bgcolor char charoff valign],
          track: %i[default kind label src srclang],
          ul: %i[compact type],
          video: %i[
            autoplay
            controls
            crossorigin
            height
            loop
            muted
            playsinline
            poster
            preload
            src
            width
          ]
        }.freeze,
        T::Hash[Symbol, T::Array[Symbol]]
      )

    # Source:
    # https://gist.githubusercontent.com/ArjanSchouten/0b8574a6ad7f5065a5e7/raw/bf4d4a6becc3bd8e9840839971011db87e5ec68c/HTML%2520boolean%2520attributes%2520list
    BOOLEAN_ATTRIBUTES =
      T.let(
        %i[
          async
          autocomplete
          autofocus
          autoplay
          border
          challenge
          checked
          compact
          contenteditable
          controls
          default
          defer
          disabled
          formNoValidate
          frameborder
          hidden
          indeterminate
          ismap
          loop
          multiple
          muted
          nohref
          noresize
          noshade
          novalidate
          nowrap
          open
          readonly
          required
          reversed
          scoped
          scrolling
          seamless
          selected
          sortable
          spellcheck
          translate
        ].freeze,
        T::Array[Symbol]
      )

    sig { params(tag: Symbol).returns(T::Boolean) }
    def self.void_tag?(tag)
      VOID_TAGS.include?(tag)
    end

    sig { params(tag: Symbol).returns(T::Array[Symbol]) }
    def self.attributes_for(tag)
      GLOBAL_ATTRIBUTES + EVENT_HANDLER_ATTRIBUTES + ATTRIBUTES.fetch(tag, [])
    end

    sig { params(attribute: Symbol).returns(T::Boolean) }
    def self.boolean_attribute?(attribute)
      BOOLEAN_ATTRIBUTES.include?(attribute)
    end

    sig { params(attribute: Symbol).returns(T::Boolean) }
    def self.event_handler_attribute?(attribute)
      EVENT_HANDLER_ATTRIBUTES.include?(attribute)
    end
  end
end
