# frozen_string_literal: true
class State < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::Component::StyleSheets.new(self, [import?("./state.css")].compact)
  begin
    # SourceMapMark:2:QnV0dG9uID0gaW1wb3J0ICIvY29tcG9uZW50cy9CdXR0b24i
    Button = import "/components/Button"

    # SourceMapMark:4:ZGVmIGluaXRpYWxpemUgPQ==
    def initialize
      # SourceMapMark:2:QnV0dG9uID0gaW1wb3J0ICIvY29tcG9uZW50cy9CdXR0b24i # SourceMapMark:5:QGNvdW50ID0gMA==
      update!(
        # SourceMapMark:5:QGNvdW50ID0gMA==
        @count = 0
      )
    end

    # SourceMapMark:7:ZGVmIGhhbmRsZV9pbmNyZW1lbnQgPQ==
    def handle_increment
      # SourceMapMark:2:QnV0dG9uID0gaW1wb3J0ICIvY29tcG9uZW50cy9CdXR0b24i # SourceMapMark:8:QGNvdW50ICs9IDE=
      update!(@count += 1)
    end

    # SourceMapMark:10:ZGVmIGhhbmRsZV9kZWNyZW1lbnQgPQ==
    def handle_decrement
      # SourceMapMark:2:QnV0dG9uID0gaW1wb3J0ICIvY29tcG9uZW50cy9CdXR0b24i # SourceMapMark:11:QGNvdW50IC09IDE=
      update!(@count -= 1)
    end

    # SourceMapMark:13:ZGVmIGhhbmRsZV9yZXNldCA9
    def handle_reset
      # SourceMapMark:2:QnV0dG9uID0gaW1wb3J0ICIvY29tcG9uZW50cy9CdXR0b24i # SourceMapMark:14:QGNvdW50ID0gMA==
      update!(
        # SourceMapMark:14:QGNvdW50ID0gMA==
        @count = 0
      )
    end
    nil
  end
  public def render
    [
      H[
        :head,
        H[:title, "Events demo", **self.class.merge_props({ class: :__title })],
        H[
          :meta,
          **self.class.merge_props(
            { class: :__meta },
            { name: "description", content: "events demo" }
          )
        ],
        **self.class.merge_props({ class: :__head })
      ],
      H[:h2, "Events demo", **self.class.merge_props({ class: :__h2 })],
      H[
        :p,
        "Current count: ",
        H[
          :output,
          # SourceMapMark:22:QGNvdW50,
          @count,
          **self.class.merge_props(
            { class: :__output },
            # SourceMapMark:22:e2NsYXNzOiB7IGJlbG93WmVybzogQGNvdW50IDwgMCB9fQ==,
            { class: { belowZero: @count < 0 } }
          )
        ],
        **self.class.merge_props({ class: :__p })
      ],
      H[
        :div,
        H[
          Button,
          "Increment",
          **self.class.merge_props(
            { class: :__Button },
            # SourceMapMark:24:eyJvbmNsaWNrIiA9PiBoYW5kbGVfaW5jcmVtZW50LH0=,
            { onclick: H.callback(self, :handle_increment) }
          )
        ],
        H[
          Button,
          "Decrement",
          **self.class.merge_props(
            { class: :__Button },
            # SourceMapMark:25:eyJvbmNsaWNrIiA9PiBoYW5kbGVfZGVjcmVtZW50LH0=,
            { onclick: H.callback(self, :handle_decrement) }
          )
        ],
        H[
          Button,
          "Reset",
          **self.class.merge_props(
            { class: :__Button },
            # SourceMapMark:26:eyJvbmNsaWNrIiA9PiBoYW5kbGVfcmVzZXQsfQ==,
            { onclick: H.callback(self, :handle_reset) }
          )
        ],
        **self.class.merge_props({ class: :__div }, { class: :buttons })
      ]
    ].flatten
  end
end
Default = State
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
