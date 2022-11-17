```mermaid
graph LR
  subgraph routes
    ROUTE____app__pages__docs__haml-transform__page.haml["/docs/haml-transform"]
    ROUTE____app__pages__docs__callbacks__page.haml["/docs/callbacks"]
    ROUTE____app__pages__docs__images__page.haml["/docs/images"]
    ROUTE____app__pages__docs__faq__page.haml["/docs/faq"]
    ROUTE____app__pages__docs__reusing-components__page.haml["/docs/reusing-components"]
    ROUTE____app__pages__docs__data-fetching__page.haml["/docs/data-fetching"]
    ROUTE____app__pages__docs__state__page.haml["/docs/state"]
    ROUTE____app__pages__docs__why-mayu__page.haml["/docs/why-mayu"]
    ROUTE____app__pages__docs__components__page.haml["/docs/components"]
    ROUTE____app__pages__docs__getting-started__page.haml["/docs/getting-started"]
    ROUTE____app__pages__docs__deployment__page.haml["/docs/deployment"]
    ROUTE____app__pages__docs__concepts__page.haml["/docs/concepts"]
    ROUTE____app__pages__docs__routing__page.haml["/docs/routing"]
    ROUTE____app__pages__docs__syntax__page.haml["/docs/syntax"]
    ROUTE____app__pages__docs__lifecycle-methods__page.haml["/docs/lifecycle-methods"]
    ROUTE____app__pages__docs__stylesheets__page.haml["/docs/stylesheets"]
    ROUTE____app__pages__docs__page.haml["/docs"]
    ROUTE____app__pages__demos__svg__page.haml["/demos/svg"]
    ROUTE____app__pages__demos__tree__page.haml["/demos/tree"]
    ROUTE____app__pages__demos__form__page.haml["/demos/form"]
    ROUTE____app__pages__demos__images__page.haml["/demos/images"]
    ROUTE____app__pages__demos__pokemon__:id__page.haml["/demos/pokemon/:id"]
    ROUTE____app__pages__demos__pokemon__page.haml["/demos/pokemon"]
    ROUTE____app__pages__demos__life__page.haml["/demos/life"]
    ROUTE____app__pages__demos__exceptions__page.haml["/demos/exceptions"]
    ROUTE____app__pages__demos__todo__page.haml["/demos/todo"]
    ROUTE____app__pages__demos__events__page.haml["/demos/events"]
    ROUTE____app__pages__demos__i18n__page.haml["/demos/i18n"]
    ROUTE____app__pages__demos__page.haml["/demos"]
    ROUTE____app__pages__page.haml["/"]
  end
  ROUTE____app__pages__docs__haml-transform__page.haml-->__app__pages__docs__haml-transform__page.haml
  ROUTE____app__pages__docs__callbacks__page.haml-->__app__pages__docs__callbacks__page.haml
  ROUTE____app__pages__docs__images__page.haml-->__app__pages__docs__images__page.haml
  ROUTE____app__pages__docs__faq__page.haml-->__app__pages__docs__faq__page.haml
  ROUTE____app__pages__docs__reusing-components__page.haml-->__app__pages__docs__reusing-components__page.haml
  ROUTE____app__pages__docs__data-fetching__page.haml-->__app__pages__docs__data-fetching__page.haml
  ROUTE____app__pages__docs__state__page.haml-->__app__pages__docs__state__page.haml
  ROUTE____app__pages__docs__why-mayu__page.haml-->__app__pages__docs__why-mayu__page.haml
  ROUTE____app__pages__docs__components__page.haml-->__app__pages__docs__components__page.haml
  ROUTE____app__pages__docs__getting-started__page.haml-->__app__pages__docs__getting-started__page.haml
  ROUTE____app__pages__docs__deployment__page.haml-->__app__pages__docs__deployment__page.haml
  ROUTE____app__pages__docs__concepts__page.haml-->__app__pages__docs__concepts__page.haml
  ROUTE____app__pages__docs__routing__page.haml-->__app__pages__docs__routing__page.haml
  ROUTE____app__pages__docs__syntax__page.haml-->__app__pages__docs__syntax__page.haml
  ROUTE____app__pages__docs__lifecycle-methods__page.haml-->__app__pages__docs__lifecycle-methods__page.haml
  ROUTE____app__pages__docs__stylesheets__page.haml-->__app__pages__docs__stylesheets__page.haml
  ROUTE____app__pages__docs__page.haml-->__app__pages__docs__page.haml
  ROUTE____app__pages__demos__svg__page.haml-->__app__pages__demos__svg__page.haml
  ROUTE____app__pages__demos__tree__page.haml-->__app__pages__demos__tree__page.haml
  ROUTE____app__pages__demos__form__page.haml-->__app__pages__demos__form__page.haml
  ROUTE____app__pages__demos__images__page.haml-->__app__pages__demos__images__page.haml
  ROUTE____app__pages__demos__pokemon__:id__page.haml-->__app__pages__demos__pokemon__:id__page.haml
  ROUTE____app__pages__demos__pokemon__page.haml-->__app__pages__demos__pokemon__page.haml
  ROUTE____app__pages__demos__life__page.haml-->__app__pages__demos__life__page.haml
  ROUTE____app__pages__demos__exceptions__page.haml-->__app__pages__demos__exceptions__page.haml
  ROUTE____app__pages__demos__todo__page.haml-->__app__pages__demos__todo__page.haml
  ROUTE____app__pages__demos__events__page.haml-->__app__pages__demos__events__page.haml
  ROUTE____app__pages__demos__i18n__page.haml-->__app__pages__demos__i18n__page.haml
  ROUTE____app__pages__demos__page.haml-->__app__pages__demos__page.haml
  ROUTE____app__pages__page.haml-->__app__pages__page.haml
  subgraph PATH__["/"]
    subgraph PATH__app["/app"]
      subgraph PATH__app__components["/app/components"]
        subgraph PATH__app__components__Layout["/app/components/Layout"]
          subgraph PATH__app__components__Layout__Footer["/app/components/Layout/Footer"]
            __app__components__Layout__Footer__Badge.haml["Badge.haml"]
          end
          __app__components__Layout__MaxWidth.haml["MaxWidth.haml"]
          __app__components__Layout__Header.css["fab:fa-css3 Header.css&nbsp;"]
          __app__components__Layout__Header.haml["Header.haml"]
          __app__components__Layout__Footer.haml["Footer.haml"]
          __app__components__Layout__Heading.css["fab:fa-css3 Heading.css&nbsp;"]
          __app__components__Layout__Heading.haml["Heading.haml"]
          __app__components__Layout__FullWidthPageWithMenu.haml["FullWidthPageWithMenu.haml"]
          __app__components__Layout__Menu.haml["Menu.haml"]
          __app__components__Layout__MenuItem.haml["MenuItem.haml"]
        end
        subgraph PATH__app__components__UI["/app/components/UI"]
          subgraph PATH__app__components__UI__Icon["/app/components/UI/Icon"]
            __app__components__UI__Icon__arrows-rotate-solid.svg["arrows-rotate-solid.svg"]
            __app__components__UI__Icon__bars-solid.svg["bars-solid.svg"]
            __app__components__UI__Icon__cloud-arrow-down-solid.svg["cloud-arrow-down-solid.svg"]
            __app__components__UI__Icon__code-solid.svg["code-solid.svg"]
            __app__components__UI__Icon__code-compare-solid.svg["code-compare-solid.svg"]
            __app__components__UI__Icon__code-pull-request-solid.svg["code-pull-request-solid.svg"]
            __app__components__UI__Icon__dice-solid.svg["dice-solid.svg"]
            __app__components__UI__Icon__file-code-solid.svg["file-code-solid.svg"]
            __app__components__UI__Icon__file-image-solid.svg["file-image-solid.svg"]
            __app__components__UI__Icon__file-lines-solid.svg["file-lines-solid.svg"]
            __app__components__UI__Icon__file-solid.svg["file-solid.svg"]
            __app__components__UI__Icon__filter-solid.svg["filter-solid.svg"]
            __app__components__UI__Icon__fire-solid.svg["fire-solid.svg"]
            __app__components__UI__Icon__flask-solid.svg["flask-solid.svg"]
            __app__components__UI__Icon__folder-open-solid.svg["folder-open-solid.svg"]
            __app__components__UI__Icon__folder-solid.svg["folder-solid.svg"]
            __app__components__UI__Icon__forward-step-solid.svg["forward-step-solid.svg"]
            __app__components__UI__Icon__gauge-high-solid.svg["gauge-high-solid.svg"]
            __app__components__UI__Icon__gauge-solid.svg["gauge-solid.svg"]
            __app__components__UI__Icon__gem-solid.svg["gem-solid.svg"]
            __app__components__UI__Icon__github.svg["github.svg"]
            __app__components__UI__Icon__globe-solid.svg["globe-solid.svg"]
            __app__components__UI__Icon__heart-solid.svg["heart-solid.svg"]
            __app__components__UI__Icon__html5.svg["html5.svg"]
            __app__components__UI__Icon__keyboard-solid.svg["keyboard-solid.svg"]
            __app__components__UI__Icon__language-solid.svg["language-solid.svg"]
            __app__components__UI__Icon__laptop-code-solid.svg["laptop-code-solid.svg"]
            __app__components__UI__Icon__link-solid.svg["link-solid.svg"]
            __app__components__UI__Icon__minus-solid.svg["minus-solid.svg"]
            __app__components__UI__Icon__network-wired-solid.svg["network-wired-solid.svg"]
            __app__components__UI__Icon__pause-solid.svg["pause-solid.svg"]
            __app__components__UI__Icon__person-digging-solid.svg["person-digging-solid.svg"]
            __app__components__UI__Icon__play-solid.svg["play-solid.svg"]
            __app__components__UI__Icon__plus-solid.svg["plus-solid.svg"]
            __app__components__UI__Icon__question-solid.svg["question-solid.svg"]
            __app__components__UI__Icon__rocket-solid.svg["rocket-solid.svg"]
            __app__components__UI__Icon__seedling-solid.svg["seedling-solid.svg"]
            __app__components__UI__Icon__server-solid.svg["server-solid.svg"]
            __app__components__UI__Icon__square-github.svg["square-github.svg"]
            __app__components__UI__Icon__star-solid.svg["star-solid.svg"]
            __app__components__UI__Icon__up-right-from-square-solid.svg["up-right-from-square-solid.svg"]
            __app__components__UI__Icon__wand-magic-sparkles-solid.svg["wand-magic-sparkles-solid.svg"]
            __app__components__UI__Icon__xmark-solid.svg["xmark-solid.svg"]
            __app__components__UI__Icon__Icon.haml["Icon.haml"]
          end
          subgraph PATH__app__components__UI__Breadcrumbs["/app/components/UI/Breadcrumbs"]
            __app__components__UI__Breadcrumbs__Link.haml["Link.haml"]
            __app__components__UI__Breadcrumbs__Separator.haml["Separator.haml"]
            __app__components__UI__Breadcrumbs__Breadcrumbs.haml["Breadcrumbs.haml"]
          end
          subgraph PATH__app__components__UI__Spinner["/app/components/UI/Spinner"]
            __app__components__UI__Spinner__90-ring-with-bg.svg["90-ring-with-bg.svg"]
            __app__components__UI__Spinner__Spinner.haml["Spinner.haml"]
          end
          __app__components__UI__Link.haml["Link.haml"]
          __app__components__UI__Card.haml["Card.haml"]
          __app__components__UI__Details.haml["Details.haml"]
          __app__components__UI__Highlight.css["fab:fa-css3 Highlight.css&nbsp;"]
          __app__components__UI__Highlight.haml["Highlight.haml"]
          __app__components__UI__YouTubeVideo.haml["YouTubeVideo.haml"]
          __app__components__UI__Image.haml["Image.haml"]
          __app__components__UI__Hr.haml["Hr.haml"]
          __app__components__UI__Tabs.haml["Tabs.haml"]
        end
        subgraph PATH__app__components__Form["/app/components/Form"]
          __app__components__Form__Fieldset.haml["Fieldset.haml"]
          __app__components__Form__Button.haml["Button.haml"]
          __app__components__Form__Input.haml["Input.haml"]
          __app__components__Form__Select.haml["Select.haml"]
          __app__components__Form__Checkbox.haml["Checkbox.haml"]
        end
        __app__components__Clock.haml["Clock.haml"]
        __app__components__UnderConstruction.haml["UnderConstruction.haml"]
        __app__components__Markdown.haml["Markdown.haml"]
      end
      subgraph PATH__app__pages["/app/pages"]
        subgraph PATH__app__pages__docs["/app/pages/docs"]
          subgraph PATH__app__pages__docs__haml-transform["/app/pages/docs/haml-transform"]
            __app__pages__docs__haml-transform__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__callbacks["/app/pages/docs/callbacks"]
            __app__pages__docs__callbacks__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__images["/app/pages/docs/images"]
            __app__pages__docs__images__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__faq["/app/pages/docs/faq"]
            __app__pages__docs__faq__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__reusing-components["/app/pages/docs/reusing-components"]
            __app__pages__docs__reusing-components__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__data-fetching["/app/pages/docs/data-fetching"]
            __app__pages__docs__data-fetching__Pokemon.haml["Pokemon.haml"]
            __app__pages__docs__data-fetching__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__state["/app/pages/docs/state"]
            __app__pages__docs__state__Example.haml["Example.haml"]
            __app__pages__docs__state__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__why-mayu["/app/pages/docs/why-mayu"]
            __app__pages__docs__why-mayu__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__components["/app/pages/docs/components"]
            __app__pages__docs__components__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__getting-started["/app/pages/docs/getting-started"]
            __app__pages__docs__getting-started__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__deployment["/app/pages/docs/deployment"]
            __app__pages__docs__deployment__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__docs__deployment__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__concepts["/app/pages/docs/concepts"]
            __app__pages__docs__concepts__no-cache-fs8.png["fa:fa-image no-cache-fs8.png&nbsp;"]
            __app__pages__docs__concepts__disk-cache-fs8.png["fa:fa-image disk-cache-fs8.png&nbsp;"]
            __app__pages__docs__concepts__memory-cache-fs8.png["fa:fa-image memory-cache-fs8.png&nbsp;"]
            __app__pages__docs__concepts__metrics-fs8.png["fa:fa-image metrics-fs8.png&nbsp;"]
            __app__pages__docs__concepts__hot-reload-fs8.png["fa:fa-image hot-reload-fs8.png&nbsp;"]
            __app__pages__docs__concepts__global-scale-fs8.png["fa:fa-image global-scale-fs8.png&nbsp;"]
            __app__pages__docs__concepts__haml-fs8.png["fa:fa-image haml-fs8.png&nbsp;"]
            __app__pages__docs__concepts__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__routing["/app/pages/docs/routing"]
            __app__pages__docs__routing__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__syntax["/app/pages/docs/syntax"]
            __app__pages__docs__syntax__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__lifecycle-methods["/app/pages/docs/lifecycle-methods"]
            __app__pages__docs__lifecycle-methods__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__stylesheets["/app/pages/docs/stylesheets"]
            __app__pages__docs__stylesheets__page.haml["page.haml"]
          end
          __app__pages__docs__Details.haml["Details.haml"]
          __app__pages__docs__layout.haml["layout.haml"]
          __app__pages__docs__Markdown.haml["Markdown.haml"]
          __app__pages__docs__CurrentFlyRegionLink.haml["CurrentFlyRegionLink.haml"]
          __app__pages__docs__page.haml["page.haml"]
          __app__pages__docs__404.haml["404.haml"]
        end
        subgraph PATH__app__pages__demos["/app/pages/demos"]
          subgraph PATH__app__pages__demos__svg["/app/pages/demos/svg"]
            __app__pages__demos__svg__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__tree["/app/pages/demos/tree"]
            __app__pages__demos__tree__FileContents.haml["FileContents.haml"]
            __app__pages__demos__tree__Name.haml["Name.haml"]
            __app__pages__demos__tree__FileEntry.haml["FileEntry.haml"]
            __app__pages__demos__tree__Directory.haml["Directory.haml"]
            __app__pages__demos__tree__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__form["/app/pages/demos/form"]
            __app__pages__demos__form__LogInForm.css["fab:fa-css3 LogInForm.css&nbsp;"]
            __app__pages__demos__form__LogInForm.haml["LogInForm.haml"]
            __app__pages__demos__form__Elements.haml["Elements.haml"]
            __app__pages__demos__form__TransferList.css["fab:fa-css3 TransferList.css&nbsp;"]
            __app__pages__demos__form__TransferList.haml["TransferList.haml"]
            __app__pages__demos__form__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__form__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__images["/app/pages/demos/images"]
            __app__pages__demos__images__comuna-13.jpeg["comuna-13.jpeg"]
            __app__pages__demos__images__colombia-map-flag.png["fa:fa-image colombia-map-flag.png&nbsp;"]
            __app__pages__demos__images__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__pokemon["/app/pages/demos/pokemon"]
            subgraph PATH__app__pages__demos__pokemon__:id["/app/pages/demos/pokemon/:id"]
              __app__pages__demos__pokemon__:id__page.haml["page.haml"]
            end
            __app__pages__demos__pokemon__layout.haml["layout.haml"]
            __app__pages__demos__pokemon__Filter.haml["Filter.haml"]
            __app__pages__demos__pokemon__Pagination.css["fab:fa-css3 Pagination.css&nbsp;"]
            __app__pages__demos__pokemon__Pagination.haml["Pagination.haml"]
            __app__pages__demos__pokemon__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__life["/app/pages/demos/life"]
            __app__pages__demos__life__Cell.haml["Cell.haml"]
            __app__pages__demos__life__GameGrid.haml["GameGrid.haml"]
            __app__pages__demos__life__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__exceptions["/app/pages/demos/exceptions"]
            __app__pages__demos__exceptions__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__todo["/app/pages/demos/todo"]
            __app__pages__demos__todo__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__events["/app/pages/demos/events"]
            __app__pages__demos__events__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__i18n["/app/pages/demos/i18n"]
            __app__pages__demos__i18n__page.haml["page.haml"]
          end
          __app__pages__demos__layout.haml["layout.haml"]
          __app__pages__demos__ButtonGame.haml["ButtonGame.haml"]
          __app__pages__demos__page.haml["page.haml"]
        end
        __app__pages__layout.css["fab:fa-css3 layout.css&nbsp;"]
        __app__pages__layout.haml["layout.haml"]
        __app__pages__Intro.css["fab:fa-css3 Intro.css&nbsp;"]
        __app__pages__Intro.haml["Intro.haml"]
        __app__pages__Section.haml["Section.haml"]
        __app__pages__Highlight.haml["Highlight.haml"]
        __app__pages__HighlightsSection.haml["HighlightsSection.haml"]
        __app__pages__Counter.haml["Counter.haml"]
        __app__pages__CounterSection.haml["CounterSection.haml"]
        __app__pages__FeatureThing.haml["FeatureThing.haml"]
        __app__pages__FeatureSection.haml["FeatureSection.haml"]
        __app__pages__ClockSection.haml["ClockSection.haml"]
        __app__pages__page.css["fab:fa-css3 page.css&nbsp;"]
        __app__pages__page.haml["page.haml"]
        __app__pages__404.haml["404.haml"]
      end
      __app__root.css["fab:fa-css3 root.css&nbsp;"]
      __app__root.haml["root.haml"]
    end
  end
  __app__root.haml-->__app__root.css
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__arrows-rotate-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__bars-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__cloud-arrow-down-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__code-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__code-compare-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__code-pull-request-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__dice-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__file-code-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__file-image-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__file-lines-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__file-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__filter-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__fire-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__flask-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__folder-open-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__folder-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__forward-step-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__gauge-high-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__gauge-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__gem-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__github.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__globe-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__heart-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__html5.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__keyboard-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__language-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__laptop-code-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__link-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__minus-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__network-wired-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__pause-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__person-digging-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__play-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__plus-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__question-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__rocket-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__seedling-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__server-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__square-github.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__star-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__up-right-from-square-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__wand-magic-sparkles-solid.svg
  __app__components__UI__Icon__Icon.haml-->__app__components__UI__Icon__xmark-solid.svg
  __app__components__Layout__Header.haml-->__app__components__Layout__MaxWidth.haml
  __app__components__Layout__Header.haml-->__app__components__UI__Icon__Icon.haml
  __app__components__Layout__Header.haml-->__app__components__Layout__Header.css
  __app__components__Layout__Footer.haml-->__app__components__Layout__MaxWidth.haml
  __app__components__Layout__Footer.haml-->__app__components__Layout__Footer__Badge.haml
  __app__pages__layout.haml-->__app__components__Layout__Header.haml
  __app__pages__layout.haml-->__app__components__Layout__Footer.haml
  __app__pages__layout.haml-->__app__pages__layout.css
  __app__pages__Intro.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__Intro.haml-->__app__pages__Intro.css
  __app__pages__Section.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__Highlight.haml-->__app__components__UI__Icon__Icon.haml
  __app__pages__HighlightsSection.haml-->__app__components__UI__Link.haml
  __app__pages__HighlightsSection.haml-->__app__pages__Section.haml
  __app__pages__HighlightsSection.haml-->__app__pages__Highlight.haml
  __app__components__Layout__Heading.haml-->__app__components__Layout__Heading.css
  __app__components__UI__Details.haml-->__app__components__UI__Card.haml
  __app__components__UI__Highlight.haml-->__app__components__UI__Highlight.css
  __app__pages__Counter.haml-->__app__components__UI__Card.haml
  __app__pages__CounterSection.haml-->__app__components__Layout__Heading.haml
  __app__pages__CounterSection.haml-->__app__components__UI__Link.haml
  __app__pages__CounterSection.haml-->__app__components__UI__Details.haml
  __app__pages__CounterSection.haml-->__app__components__UI__Highlight.haml
  __app__pages__CounterSection.haml-->__app__pages__Counter.haml
  __app__pages__CounterSection.haml-->__app__pages__Section.haml
  __app__pages__FeatureSection.haml-->__app__components__UI__Icon__Icon.haml
  __app__pages__FeatureSection.haml-->__app__components__UI__Link.haml
  __app__pages__FeatureSection.haml-->__app__components__Layout__Heading.haml
  __app__pages__FeatureSection.haml-->__app__pages__Section.haml
  __app__pages__FeatureSection.haml-->__app__pages__FeatureThing.haml
  __app__pages__ClockSection.haml-->__app__components__Clock.haml
  __app__pages__ClockSection.haml-->__app__components__UI__Link.haml
  __app__pages__ClockSection.haml-->__app__pages__Section.haml
  __app__pages__page.haml-->__app__pages__Intro.haml
  __app__pages__page.haml-->__app__pages__HighlightsSection.haml
  __app__pages__page.haml-->__app__pages__CounterSection.haml
  __app__pages__page.haml-->__app__pages__FeatureSection.haml
  __app__pages__page.haml-->__app__pages__ClockSection.haml
  __app__pages__page.haml-->__app__pages__page.css
  __app__components__Layout__FullWidthPageWithMenu.haml-->__app__components__Layout__MaxWidth.haml
  __app__components__UI__Breadcrumbs__Breadcrumbs.haml-->__app__components__Layout__MaxWidth.haml
  __app__components__UI__Breadcrumbs__Breadcrumbs.haml-->__app__components__UI__Breadcrumbs__Link.haml
  __app__components__UI__Breadcrumbs__Breadcrumbs.haml-->__app__components__UI__Breadcrumbs__Separator.haml
  __app__components__UnderConstruction.haml-->__app__components__UI__Icon__Icon.haml
  __app__components__UnderConstruction.haml-->__app__components__UI__Link.haml
  __app__components__UnderConstruction.haml-->__app__components__UI__Card.haml
  __app__pages__docs__layout.haml-->__app__components__Layout__FullWidthPageWithMenu.haml
  __app__pages__docs__layout.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__layout.haml-->__app__components__Layout__Menu.haml
  __app__pages__docs__layout.haml-->__app__components__Layout__MenuItem.haml
  __app__pages__docs__layout.haml-->__app__pages__docs__Details.haml
  __app__pages__docs__layout.haml-->__app__components__UI__Breadcrumbs__Breadcrumbs.haml
  __app__pages__docs__layout.haml-->__app__components__UnderConstruction.haml
  __app__components__Markdown.haml-->__app__components__UI__Highlight.haml
  __app__pages__docs__Markdown.haml-->__app__components__Markdown.haml
  __app__pages__docs__Markdown.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__Markdown.haml-->__app__components__UI__Link.haml
  __app__pages__docs__CurrentFlyRegionLink.haml-->__app__components__UI__Link.haml
  __app__pages__docs__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__page.haml-->__app__pages__docs__CurrentFlyRegionLink.haml
  __app__pages__docs__haml-transform__page.haml-->__app__components__UI__Details.haml
  __app__pages__docs__haml-transform__page.haml-->__app__components__UI__Highlight.haml
  __app__pages__docs__callbacks__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__images__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__faq__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__faq__page.haml-->__app__components__UI__Details.haml
  __app__pages__docs__reusing-components__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__data-fetching__Pokemon.haml-->__app__components__UI__Highlight.haml
  __app__pages__docs__data-fetching__page.haml-->__app__components__UI__Details.haml
  __app__pages__docs__data-fetching__page.haml-->__app__components__UI__Highlight.haml
  __app__pages__docs__data-fetching__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__data-fetching__page.haml-->__app__pages__docs__data-fetching__Pokemon.haml
  __app__pages__docs__state__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__state__page.haml-->__app__components__UI__Card.haml
  __app__pages__docs__state__page.haml-->__app__components__UI__Highlight.haml
  __app__pages__docs__state__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__state__page.haml-->__app__pages__docs__state__Example.haml
  __app__pages__docs__why-mayu__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__components__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__getting-started__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__deployment__page.haml-->__app__components__UI__YouTubeVideo.haml
  __app__pages__docs__deployment__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__deployment__page.haml-->__app__pages__docs__CurrentFlyRegionLink.haml
  __app__pages__docs__deployment__page.haml-->__app__pages__docs__deployment__page.css
  __app__pages__docs__concepts__page.haml-->__app__components__UI__Card.haml
  __app__pages__docs__concepts__page.haml-->__app__components__UI__Image.haml
  __app__pages__docs__concepts__page.haml-->__app__components__UI__Link.haml
  __app__pages__docs__concepts__page.haml-->__app__components__UI__YouTubeVideo.haml
  __app__pages__docs__concepts__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__concepts__page.haml-->__app__pages__docs__concepts__no-cache-fs8.png
  __app__pages__docs__concepts__page.haml-->__app__pages__docs__concepts__disk-cache-fs8.png
  __app__pages__docs__concepts__page.haml-->__app__pages__docs__concepts__memory-cache-fs8.png
  __app__pages__docs__concepts__page.haml-->__app__pages__docs__concepts__metrics-fs8.png
  __app__pages__docs__concepts__page.haml-->__app__pages__docs__concepts__hot-reload-fs8.png
  __app__pages__docs__concepts__page.haml-->__app__pages__docs__concepts__global-scale-fs8.png
  __app__pages__docs__concepts__page.haml-->__app__pages__docs__concepts__haml-fs8.png
  __app__pages__docs__routing__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__syntax__page.haml-->__app__components__UI__Highlight.haml
  __app__pages__docs__syntax__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__lifecycle-methods__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__stylesheets__page.haml-->__app__pages__docs__Markdown.haml
  __app__pages__docs__404.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__layout.haml-->__app__components__Layout__FullWidthPageWithMenu.haml
  __app__pages__demos__layout.haml-->__app__components__Layout__Menu.haml
  __app__pages__demos__layout.haml-->__app__components__Layout__MenuItem.haml
  __app__pages__demos__layout.haml-->__app__components__UI__Breadcrumbs__Breadcrumbs.haml
  __app__pages__demos__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__page.haml-->__app__pages__demos__ButtonGame.haml
  __app__pages__demos__svg__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__svg__page.haml-->__app__components__Clock.haml
  __app__pages__demos__tree__FileContents.haml-->__app__components__UI__Highlight.haml
  __app__pages__demos__tree__Name.haml-->__app__components__UI__Icon__Icon.haml
  __app__pages__demos__tree__FileEntry.haml-->__app__components__UI__Icon__Icon.haml
  __app__pages__demos__tree__FileEntry.haml-->__app__pages__demos__tree__Name.haml
  __app__pages__demos__tree__Directory.haml-->__app__components__UI__Icon__Icon.haml
  __app__pages__demos__tree__Directory.haml-->__app__pages__demos__tree__Name.haml
  __app__pages__demos__tree__Directory.haml-->__app__pages__demos__tree__FileEntry.haml
  __app__pages__demos__tree__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__tree__page.haml-->__app__components__UI__Card.haml
  __app__pages__demos__tree__page.haml-->__app__pages__demos__tree__FileContents.haml
  __app__pages__demos__tree__page.haml-->__app__pages__demos__tree__Directory.haml
  __app__pages__demos__form__LogInForm.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__form__LogInForm.haml-->__app__components__UI__Details.haml
  __app__pages__demos__form__LogInForm.haml-->__app__components__UI__YouTubeVideo.haml
  __app__pages__demos__form__LogInForm.haml-->__app__pages__demos__form__LogInForm.css
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Button.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Input.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Select.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Checkbox.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Button.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Input.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Select.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Checkbox.haml
  __app__pages__demos__form__TransferList.haml-->__app__pages__demos__form__TransferList.css
  __app__pages__demos__form__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__form__page.haml-->__app__components__UI__Hr.haml
  __app__pages__demos__form__page.haml-->__app__components__UI__Tabs.haml
  __app__pages__demos__form__page.haml-->__app__pages__demos__form__LogInForm.haml
  __app__pages__demos__form__page.haml-->__app__pages__demos__form__Elements.haml
  __app__pages__demos__form__page.haml-->__app__pages__demos__form__TransferList.haml
  __app__pages__demos__form__page.haml-->__app__pages__demos__form__page.css
  __app__pages__demos__images__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__images__page.haml-->__app__components__UI__Image.haml
  __app__pages__demos__images__page.haml-->__app__pages__demos__images__comuna-13.jpeg
  __app__pages__demos__images__page.haml-->__app__pages__demos__images__colombia-map-flag.png
  __app__pages__demos__pokemon__layout.haml-->__app__components__Layout__Heading.haml
  __app__components__UI__Spinner__Spinner.haml-->__app__components__UI__Spinner__90-ring-with-bg.svg
  __app__pages__demos__pokemon__Filter.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__pokemon__Filter.haml-->__app__components__Form__Input.haml
  __app__pages__demos__pokemon__Filter.haml-->__app__components__Form__Button.haml
  __app__pages__demos__pokemon__Filter.haml-->__app__components__UI__Icon__Icon.haml
  __app__pages__demos__pokemon__Pagination.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__pokemon__Pagination.haml-->__app__components__Form__Button.haml
  __app__pages__demos__pokemon__Pagination.haml-->__app__pages__demos__pokemon__Pagination.css
  __app__pages__demos__pokemon__page.haml-->__app__components__UI__Spinner__Spinner.haml
  __app__pages__demos__pokemon__page.haml-->__app__pages__demos__pokemon__Filter.haml
  __app__pages__demos__pokemon__page.haml-->__app__pages__demos__pokemon__Pagination.haml
  __app__pages__demos__life__GameGrid.haml-->__app__pages__demos__life__Cell.haml
  __app__pages__demos__life__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__life__page.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__life__page.haml-->__app__components__Form__Input.haml
  __app__pages__demos__life__page.haml-->__app__components__Form__Button.haml
  __app__pages__demos__life__page.haml-->__app__components__UI__Link.haml
  __app__pages__demos__life__page.haml-->__app__pages__demos__life__GameGrid.haml
  __app__pages__demos__exceptions__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__exceptions__page.haml-->__app__components__UI__Highlight.haml
  __app__pages__demos__exceptions__page.haml-->__app__components__UI__Card.haml
  __app__pages__demos__exceptions__page.haml-->__app__components__UI__Details.haml
  __app__pages__demos__todo__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__todo__page.haml-->__app__components__UI__Card.haml
  __app__pages__demos__todo__page.haml-->__app__components__UI__Link.haml
  __app__pages__demos__events__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__events__page.haml-->__app__components__UI__Highlight.haml
  __app__pages__demos__events__page.haml-->__app__components__UI__Card.haml
  __app__pages__demos__events__page.haml-->__app__components__UI__Details.haml
  __app__pages__demos__i18n__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__404.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__404.haml-->__app__components__Layout__Heading.haml
  class __app__root.css CSS
  class __app__components__Layout__Header.css CSS
  class __app__pages__layout.css CSS
  class __app__pages__Intro.css CSS
  class __app__components__Layout__Heading.css CSS
  class __app__components__UI__Highlight.css CSS
  class __app__pages__page.css CSS
  class __app__pages__docs__deployment__page.css CSS
  class __app__pages__docs__concepts__no-cache-fs8.png Image
  class __app__pages__docs__concepts__disk-cache-fs8.png Image
  class __app__pages__docs__concepts__memory-cache-fs8.png Image
  class __app__pages__docs__concepts__metrics-fs8.png Image
  class __app__pages__docs__concepts__hot-reload-fs8.png Image
  class __app__pages__docs__concepts__global-scale-fs8.png Image
  class __app__pages__docs__concepts__haml-fs8.png Image
  class __app__pages__demos__form__LogInForm.css CSS
  class __app__pages__demos__form__TransferList.css CSS
  class __app__pages__demos__form__page.css CSS
  class __app__pages__demos__images__colombia-map-flag.png Image
  class __app__pages__demos__pokemon__Pagination.css CSS
  style routes stroke:#09c,stroke-width:5,fill:#f0f;
  classDef cluster fill:#0003;
  classDef Ruby fill:#600,stroke:#900,stroke-width:3px;
  classDef Image fill:#069,stroke:#09c,stroke-width:3px;
  classDef CSS fill:#063,stroke:#096,stroke-width:3px;
  classDef NonExistant opacity:50%,stroke-dasharray:5px;
  linkStyle default fill:transparent,opacity:50%;
```
