```mermaid
graph TB
  subgraph routes
    ROUTE____app__pages__docs__faq__page.rux["/docs/faq"]
    ROUTE____app__pages__docs__getting-started__page.rux["/docs/getting-started"]
    ROUTE____app__pages__docs__deployment__page.rux["/docs/deployment"]
    ROUTE____app__pages__docs__page.rux["/docs"]
    ROUTE____app__pages__demos__tree__page.rux["/demos/tree"]
    ROUTE____app__pages__demos__form__page.rux["/demos/form"]
    ROUTE____app__pages__demos__pokemon__:id__page.rux["/demos/pokemon/:id"]
    ROUTE____app__pages__demos__pokemon__page.rux["/demos/pokemon"]
    ROUTE____app__pages__demos__i18n__page.rux["/demos/i18n"]
    ROUTE____app__pages__demos__page.rux["/demos"]
    ROUTE____app__pages__page.rux["/"]
  end
  ROUTE____app__pages__docs__faq__page.rux-->__app__pages__docs__faq__page.rux
  ROUTE____app__pages__docs__getting-started__page.rux-->__app__pages__docs__getting-started__page.rux
  ROUTE____app__pages__docs__deployment__page.rux-->__app__pages__docs__deployment__page.rux
  ROUTE____app__pages__docs__page.rux-->__app__pages__docs__page.rux
  ROUTE____app__pages__demos__tree__page.rux-->__app__pages__demos__tree__page.rux
  ROUTE____app__pages__demos__form__page.rux-->__app__pages__demos__form__page.rux
  ROUTE____app__pages__demos__pokemon__:id__page.rux-->__app__pages__demos__pokemon__:id__page.rux
  ROUTE____app__pages__demos__pokemon__page.rux-->__app__pages__demos__pokemon__page.rux
  ROUTE____app__pages__demos__i18n__page.rux-->__app__pages__demos__i18n__page.rux
  ROUTE____app__pages__demos__page.rux-->__app__pages__demos__page.rux
  ROUTE____app__pages__page.rux-->__app__pages__page.rux
  subgraph PATH__["/"]
    subgraph PATH__app["/app"]
      subgraph PATH__app__components["/app/components"]
        subgraph PATH__app__components__Layout["/app/components/Layout"]
          __app__components__Layout__MaxWidth.css["fab:fa-css3 MaxWidth.css&nbsp;"]
          __app__components__Layout__MaxWidth.rux["MaxWidth.rux"]
          __app__components__Layout__logo.png["fa:fa-image logo.png&nbsp;"]
          __app__components__Layout__Header.css["fab:fa-css3 Header.css&nbsp;"]
          __app__components__Layout__Header.rux["Header.rux"]
          __app__components__Layout__Footer.css["fab:fa-css3 Footer.css&nbsp;"]
          __app__components__Layout__Footer.rux["Footer.rux"]
          __app__components__Layout__Heading.css["fab:fa-css3 Heading.css&nbsp;"]
          __app__components__Layout__Heading.rux["Heading.rux"]
          __app__components__Layout__Page.css["fab:fa-css3 Page.css&nbsp;"]
          __app__components__Layout__Page.rux["Page.rux"]
          __app__components__Layout__Menu.css["fab:fa-css3 Menu.css&nbsp;"]
          __app__components__Layout__Menu.rux["Menu.rux"]
          __app__components__Layout__MenuItem.css["fab:fa-css3 MenuItem.css&nbsp;"]
          __app__components__Layout__MenuItem.rux["MenuItem.rux"]
        end
        subgraph PATH__app__components__Form["/app/components/Form"]
          __app__components__Form__Fieldset.css["fab:fa-css3 Fieldset.css&nbsp;"]
          __app__components__Form__Fieldset.rux["Fieldset.rux"]
          __app__components__Form__Button.css["fab:fa-css3 Button.css&nbsp;"]
          __app__components__Form__Button.rux["Button.rux"]
          __app__components__Form__Input.css["fab:fa-css3 Input.css&nbsp;"]
          __app__components__Form__Input.rux["Input.rux"]
          __app__components__Form__Select.css["fab:fa-css3 Select.css&nbsp;"]
          __app__components__Form__Select.rux["Select.rux"]
          __app__components__Form__Checkbox.css["fab:fa-css3 Checkbox.css&nbsp;"]
          __app__components__Form__Checkbox.rux["Checkbox.rux"]
        end
      end
      subgraph PATH__app__pages["/app/pages"]
        subgraph PATH__app__pages__docs["/app/pages/docs"]
          subgraph PATH__app__pages__docs__faq["/app/pages/docs/faq"]
            __app__pages__docs__faq__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__docs__faq__page.rux["page.rux"]
          end
          subgraph PATH__app__pages__docs__getting-started["/app/pages/docs/getting-started"]
            __app__pages__docs__getting-started__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__docs__getting-started__page.rux["page.rux"]
          end
          subgraph PATH__app__pages__docs__deployment["/app/pages/docs/deployment"]
            __app__pages__docs__deployment__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__docs__deployment__page.rux["page.rux"]
          end
          __app__pages__docs__layout.css["fab:fa-css3 layout.css&nbsp;"]
          __app__pages__docs__layout.rux["layout.rux"]
          __app__pages__docs__page.css["fab:fa-css3 page.css&nbsp;"]
          __app__pages__docs__page.rux["page.rux"]
          __app__pages__docs__404.css["fab:fa-css3 404.css&nbsp;"]
          __app__pages__docs__404.rux["404.rux"]
        end
        subgraph PATH__app__pages__demos["/app/pages/demos"]
          subgraph PATH__app__pages__demos__tree["/app/pages/demos/tree"]
            __app__pages__demos__tree__Directory.css["fab:fa-css3 Directory.css&nbsp;"]
            __app__pages__demos__tree__Directory.rux["Directory.rux"]
            __app__pages__demos__tree__FileEntry.css["fab:fa-css3 FileEntry.css&nbsp;"]
            __app__pages__demos__tree__FileEntry.rux["FileEntry.rux"]
            __app__pages__demos__tree__Entry.css["fab:fa-css3 Entry.css&nbsp;"]
            __app__pages__demos__tree__Entry.rux["Entry.rux"]
            __app__pages__demos__tree__FileContents.css["fab:fa-css3 FileContents.css&nbsp;"]
            __app__pages__demos__tree__FileContents.rux["FileContents.rux"]
            __app__pages__demos__tree__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__tree__page.rux["page.rux"]
          end
          subgraph PATH__app__pages__demos__form["/app/pages/demos/form"]
            __app__pages__demos__form__LogInForm.css["fab:fa-css3 LogInForm.css&nbsp;"]
            __app__pages__demos__form__LogInForm.rux["LogInForm.rux"]
            __app__pages__demos__form__Elements.css["fab:fa-css3 Elements.css&nbsp;"]
            __app__pages__demos__form__Elements.rux["Elements.rux"]
            __app__pages__demos__form__TransferList.css["fab:fa-css3 TransferList.css&nbsp;"]
            __app__pages__demos__form__TransferList.rux["TransferList.rux"]
            __app__pages__demos__form__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__form__page.rux["page.rux"]
          end
          subgraph PATH__app__pages__demos__pokemon["/app/pages/demos/pokemon"]
            subgraph PATH__app__pages__demos__pokemon__:id["/app/pages/demos/pokemon/:id"]
              __app__pages__demos__pokemon__:id__page.css["fab:fa-css3 page.css&nbsp;"]
              __app__pages__demos__pokemon__:id__page.rux["page.rux"]
            end
            __app__pages__demos__pokemon__layout.css["fab:fa-css3 layout.css&nbsp;"]
            __app__pages__demos__pokemon__layout.rux["layout.rux"]
            __app__pages__demos__pokemon__Pagination.css["fab:fa-css3 Pagination.css&nbsp;"]
            __app__pages__demos__pokemon__Pagination.rux["Pagination.rux"]
            __app__pages__demos__pokemon__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__pokemon__page.rux["page.rux"]
          end
          subgraph PATH__app__pages__demos__i18n["/app/pages/demos/i18n"]
            __app__pages__demos__i18n__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__i18n__page.rux["page.rux"]
          end
          __app__pages__demos__layout.css["fab:fa-css3 layout.css&nbsp;"]
          __app__pages__demos__layout.rux["layout.rux"]
          __app__pages__demos__ButtonGame.css["fab:fa-css3 ButtonGame.css&nbsp;"]
          __app__pages__demos__ButtonGame.rux["ButtonGame.rux"]
          __app__pages__demos__page.css["fab:fa-css3 page.css&nbsp;"]
          __app__pages__demos__page.rux["page.rux"]
        end
        __app__pages__Intro.css["fab:fa-css3 Intro.css&nbsp;"]
        __app__pages__Intro.rux["Intro.rux"]
        __app__pages__layout.css["fab:fa-css3 layout.css&nbsp;"]
        __app__pages__layout.rux["layout.rux"]
        __app__pages__Counter.css["fab:fa-css3 Counter.css&nbsp;"]
        __app__pages__Counter.rux["Counter.rux"]
        __app__pages__FeatureThing.css["fab:fa-css3 FeatureThing.css&nbsp;"]
        __app__pages__FeatureThing.rux["FeatureThing.rux"]
        __app__pages__page.css["fab:fa-css3 page.css&nbsp;"]
        __app__pages__page.rux["page.rux"]
        __app__pages__404.css["fab:fa-css3 404.css&nbsp;"]
        __app__pages__404.rux["404.rux"]
      end
      __app__root.css["fab:fa-css3 root.css&nbsp;"]
      __app__root.rux["root.rux"]
    end
  end
  __app__root.rux-->__app__root.css
  __app__components__Layout__MaxWidth.rux-->__app__components__Layout__MaxWidth.css
  __app__pages__Intro.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__Intro.rux-->__app__pages__Intro.css
  __app__components__Layout__Header.rux-->__app__components__Layout__MaxWidth.rux
  __app__components__Layout__Header.rux-->__app__components__Layout__logo.png
  __app__components__Layout__Header.rux-->__app__components__Layout__Header.css
  __app__components__Layout__Footer.rux-->__app__components__Layout__MaxWidth.rux
  __app__components__Layout__Footer.rux-->__app__components__Layout__Footer.css
  __app__pages__layout.rux-->__app__pages__Intro.rux
  __app__pages__layout.rux-->__app__components__Layout__Header.rux
  __app__pages__layout.rux-->__app__components__Layout__Footer.rux
  __app__pages__layout.rux-->__app__pages__layout.css
  __app__components__Layout__Heading.rux-->__app__components__Layout__Heading.css
  __app__pages__Counter.rux-->__app__pages__Counter.css
  __app__pages__FeatureThing.rux-->__app__pages__FeatureThing.css
  __app__pages__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__page.rux-->__app__pages__Counter.rux
  __app__pages__page.rux-->__app__pages__FeatureThing.rux
  __app__pages__page.rux-->__app__pages__page.css
  __app__components__Layout__Page.rux-->__app__components__Layout__MaxWidth.rux
  __app__components__Layout__Page.rux-->__app__components__Layout__Heading.rux
  __app__components__Layout__Page.rux-->__app__components__Layout__Page.css
  __app__components__Layout__Menu.rux-->__app__components__Layout__Menu.css
  __app__components__Layout__MenuItem.rux-->__app__components__Layout__MenuItem.css
  __app__pages__docs__layout.rux-->__app__components__Layout__Page.rux
  __app__pages__docs__layout.rux-->__app__components__Layout__Menu.rux
  __app__pages__docs__layout.rux-->__app__components__Layout__MenuItem.rux
  __app__pages__docs__layout.rux-->__app__pages__docs__layout.css
  __app__pages__docs__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__docs__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__docs__page.rux-->__app__pages__docs__page.css
  __app__pages__docs__faq__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__docs__faq__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__docs__faq__page.rux-->__app__pages__docs__faq__page.css
  __app__pages__docs__getting-started__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__docs__getting-started__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__docs__getting-started__page.rux-->__app__pages__docs__getting-started__page.css
  __app__pages__docs__deployment__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__docs__deployment__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__docs__deployment__page.rux-->__app__pages__docs__deployment__page.css
  __app__pages__docs__404.rux-->__app__components__Layout__Heading.rux
  __app__pages__docs__404.rux-->__app__pages__docs__404.css
  __app__pages__demos__layout.rux-->__app__components__Layout__Page.rux
  __app__pages__demos__layout.rux-->__app__components__Layout__Menu.rux
  __app__pages__demos__layout.rux-->__app__components__Layout__MenuItem.rux
  __app__pages__demos__layout.rux-->__app__pages__demos__layout.css
  __app__pages__demos__ButtonGame.rux-->__app__pages__demos__ButtonGame.css
  __app__pages__demos__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__demos__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__demos__page.rux-->__app__pages__demos__ButtonGame.rux
  __app__pages__demos__page.rux-->__app__pages__demos__page.css
  __app__pages__demos__tree__Directory.rux-->__app__pages__demos__tree__Directory.css
  __app__pages__demos__tree__FileEntry.rux-->__app__pages__demos__tree__FileEntry.css
  __app__pages__demos__tree__Entry.rux-->__app__pages__demos__tree__Directory.rux
  __app__pages__demos__tree__Entry.rux-->__app__pages__demos__tree__FileEntry.rux
  __app__pages__demos__tree__Entry.rux-->__app__pages__demos__tree__Entry.css
  __app__pages__demos__tree__FileContents.rux-->__app__pages__demos__tree__FileContents.css
  __app__pages__demos__tree__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__demos__tree__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__demos__tree__page.rux-->__app__pages__demos__tree__Entry.rux
  __app__pages__demos__tree__page.rux-->__app__pages__demos__tree__FileContents.rux
  __app__pages__demos__tree__page.rux-->__app__pages__demos__tree__page.css
  __app__components__Form__Fieldset.rux-->__app__components__Form__Fieldset.css
  __app__pages__demos__form__LogInForm.rux-->__app__components__Layout__Heading.rux
  __app__pages__demos__form__LogInForm.rux-->__app__components__Form__Fieldset.rux
  __app__pages__demos__form__LogInForm.rux-->__app__pages__demos__form__LogInForm.css
  __app__components__Form__Button.rux-->__app__components__Form__Button.css
  __app__components__Form__Input.rux-->__app__components__Form__Input.css
  __app__components__Form__Select.rux-->__app__components__Form__Select.css
  __app__components__Form__Checkbox.rux-->__app__components__Form__Checkbox.css
  __app__pages__demos__form__Elements.rux-->__app__components__Layout__Heading.rux
  __app__pages__demos__form__Elements.rux-->__app__components__Form__Fieldset.rux
  __app__pages__demos__form__Elements.rux-->__app__components__Form__Button.rux
  __app__pages__demos__form__Elements.rux-->__app__components__Form__Input.rux
  __app__pages__demos__form__Elements.rux-->__app__components__Form__Select.rux
  __app__pages__demos__form__Elements.rux-->__app__components__Form__Checkbox.rux
  __app__pages__demos__form__Elements.rux-->__app__pages__demos__form__Elements.css
  __app__pages__demos__form__TransferList.rux-->__app__components__Layout__Heading.rux
  __app__pages__demos__form__TransferList.rux-->__app__components__Form__Fieldset.rux
  __app__pages__demos__form__TransferList.rux-->__app__components__Form__Button.rux
  __app__pages__demos__form__TransferList.rux-->__app__components__Form__Input.rux
  __app__pages__demos__form__TransferList.rux-->__app__components__Form__Select.rux
  __app__pages__demos__form__TransferList.rux-->__app__components__Form__Checkbox.rux
  __app__pages__demos__form__TransferList.rux-->__app__pages__demos__form__TransferList.css
  __app__pages__demos__form__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__demos__form__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__demos__form__page.rux-->__app__pages__demos__form__LogInForm.rux
  __app__pages__demos__form__page.rux-->__app__pages__demos__form__Elements.rux
  __app__pages__demos__form__page.rux-->__app__pages__demos__form__TransferList.rux
  __app__pages__demos__form__page.rux-->__app__pages__demos__form__page.css
  __app__pages__demos__pokemon__layout.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__demos__pokemon__layout.rux-->__app__components__Layout__Heading.rux
  __app__pages__demos__pokemon__layout.rux-->__app__pages__demos__pokemon__layout.css
  __app__pages__demos__pokemon__Pagination.rux-->__app__components__Form__Fieldset.rux
  __app__pages__demos__pokemon__Pagination.rux-->__app__components__Form__Button.rux
  __app__pages__demos__pokemon__Pagination.rux-->__app__pages__demos__pokemon__Pagination.css
  __app__pages__demos__pokemon__page.rux-->__app__pages__demos__pokemon__Pagination.rux
  __app__pages__demos__pokemon__page.rux-->__app__pages__demos__pokemon__page.css
  __app__pages__demos__pokemon__:id__page.rux-->__app__pages__demos__pokemon__:id__page.css
  __app__pages__demos__i18n__page.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__demos__i18n__page.rux-->__app__components__Layout__Heading.rux
  __app__pages__demos__i18n__page.rux-->__app__pages__demos__i18n__page.css
  __app__pages__404.rux-->__app__components__Layout__MaxWidth.rux
  __app__pages__404.rux-->__app__components__Layout__Heading.rux
  __app__pages__404.rux-->__app__pages__404.css
  class __app__root.css CSS
  class __app__components__Layout__MaxWidth.css CSS
  class __app__pages__Intro.css CSS
  class __app__components__Layout__logo.png Image
  class __app__components__Layout__Header.css CSS
  class __app__components__Layout__Footer.css CSS
  class __app__pages__layout.css CSS
  class __app__components__Layout__Heading.css CSS
  class __app__pages__Counter.css CSS
  class __app__pages__FeatureThing.css CSS
  class __app__pages__page.css CSS
  class __app__components__Layout__Page.css CSS
  class __app__components__Layout__Menu.css CSS
  class __app__components__Layout__MenuItem.css CSS
  class __app__pages__docs__layout.css CSS
  class __app__pages__docs__page.css NonExistant
  class __app__pages__docs__page.css CSS
  class __app__pages__docs__faq__page.css CSS
  class __app__pages__docs__getting-started__page.css CSS
  class __app__pages__docs__deployment__page.css CSS
  class __app__pages__docs__404.css NonExistant
  class __app__pages__docs__404.css CSS
  class __app__pages__demos__layout.css NonExistant
  class __app__pages__demos__layout.css CSS
  class __app__pages__demos__ButtonGame.css CSS
  class __app__pages__demos__page.css NonExistant
  class __app__pages__demos__page.css CSS
  class __app__pages__demos__tree__Directory.css CSS
  class __app__pages__demos__tree__FileEntry.css CSS
  class __app__pages__demos__tree__Entry.css NonExistant
  class __app__pages__demos__tree__Entry.css CSS
  class __app__pages__demos__tree__FileContents.css CSS
  class __app__pages__demos__tree__page.css CSS
  class __app__components__Form__Fieldset.css CSS
  class __app__pages__demos__form__LogInForm.css CSS
  class __app__components__Form__Button.css CSS
  class __app__components__Form__Input.css CSS
  class __app__components__Form__Select.css CSS
  class __app__components__Form__Checkbox.css CSS
  class __app__pages__demos__form__Elements.css NonExistant
  class __app__pages__demos__form__Elements.css CSS
  class __app__pages__demos__form__TransferList.css CSS
  class __app__pages__demos__form__page.css CSS
  class __app__pages__demos__pokemon__layout.css NonExistant
  class __app__pages__demos__pokemon__layout.css CSS
  class __app__pages__demos__pokemon__Pagination.css CSS
  class __app__pages__demos__pokemon__page.css CSS
  class __app__pages__demos__pokemon__:id__page.css NonExistant
  class __app__pages__demos__pokemon__:id__page.css CSS
  class __app__pages__demos__i18n__page.css NonExistant
  class __app__pages__demos__i18n__page.css CSS
  class __app__pages__404.css NonExistant
  class __app__pages__404.css CSS
  style routes stroke:#09c,stroke-width:5,fill:#f0f;
  classDef cluster fill:#0003;
  classDef Ruby fill:#600,stroke:#900,stroke-width:3px;
  classDef Image fill:#069,stroke:#09c,stroke-width:3px;
  classDef CSS fill:#063,stroke:#096,stroke-width:3px;
  classDef NonExistant opacity:50%,stroke-dasharray:5px;
  linkStyle default fill:transparent,opacity:50%;
```
