```mermaid
graph TB
  subgraph routes
    ROUTE____app__pages__docs__faq__page.haml["/docs/faq"]
    ROUTE____app__pages__docs__getting-started__page.haml["/docs/getting-started"]
    ROUTE____app__pages__docs__deployment__page.haml["/docs/deployment"]
    ROUTE____app__pages__docs__page.haml["/docs"]
    ROUTE____app__pages__demos__tree__page.haml["/demos/tree"]
    ROUTE____app__pages__demos__form__page.haml["/demos/form"]
    ROUTE____app__pages__demos__pokemon__:id__page.haml["/demos/pokemon/:id"]
    ROUTE____app__pages__demos__pokemon__page.haml["/demos/pokemon"]
    ROUTE____app__pages__demos__i18n__page.haml["/demos/i18n"]
    ROUTE____app__pages__demos__page.haml["/demos"]
    ROUTE____app__pages__page.haml["/"]
  end
  ROUTE____app__pages__docs__faq__page.haml-->__app__pages__docs__faq__page.haml
  ROUTE____app__pages__docs__getting-started__page.haml-->__app__pages__docs__getting-started__page.haml
  ROUTE____app__pages__docs__deployment__page.haml-->__app__pages__docs__deployment__page.haml
  ROUTE____app__pages__docs__page.haml-->__app__pages__docs__page.haml
  ROUTE____app__pages__demos__tree__page.haml-->__app__pages__demos__tree__page.haml
  ROUTE____app__pages__demos__form__page.haml-->__app__pages__demos__form__page.haml
  ROUTE____app__pages__demos__pokemon__:id__page.haml-->__app__pages__demos__pokemon__:id__page.haml
  ROUTE____app__pages__demos__pokemon__page.haml-->__app__pages__demos__pokemon__page.haml
  ROUTE____app__pages__demos__i18n__page.haml-->__app__pages__demos__i18n__page.haml
  ROUTE____app__pages__demos__page.haml-->__app__pages__demos__page.haml
  ROUTE____app__pages__page.haml-->__app__pages__page.haml
  subgraph PATH__["/"]
    subgraph PATH__app["/app"]
      subgraph PATH__app__components["/app/components"]
        subgraph PATH__app__components__Layout["/app/components/Layout"]
          __app__components__Layout__MaxWidth.css["fab:fa-css3 MaxWidth.css&nbsp;"]
          __app__components__Layout__MaxWidth.haml["MaxWidth.haml"]
          __app__components__Layout__Heading.css["fab:fa-css3 Heading.css&nbsp;"]
          __app__components__Layout__Heading.haml["Heading.haml"]
          __app__components__Layout__logo.png["fa:fa-image logo.png&nbsp;"]
          __app__components__Layout__Header.css["fab:fa-css3 Header.css&nbsp;"]
          __app__components__Layout__Header.haml["Header.haml"]
          __app__components__Layout__Footer.css["fab:fa-css3 Footer.css&nbsp;"]
          __app__components__Layout__Footer.haml["Footer.haml"]
          __app__components__Layout__Page.css["fab:fa-css3 Page.css&nbsp;"]
          __app__components__Layout__Page.haml["Page.haml"]
          __app__components__Layout__Menu.css["fab:fa-css3 Menu.css&nbsp;"]
          __app__components__Layout__Menu.haml["Menu.haml"]
          __app__components__Layout__MenuItem.css["fab:fa-css3 MenuItem.css&nbsp;"]
          __app__components__Layout__MenuItem.haml["MenuItem.haml"]
        end
        subgraph PATH__app__components__Form["/app/components/Form"]
          __app__components__Form__Fieldset.css["fab:fa-css3 Fieldset.css&nbsp;"]
          __app__components__Form__Fieldset.haml["Fieldset.haml"]
          __app__components__Form__Button.css["fab:fa-css3 Button.css&nbsp;"]
          __app__components__Form__Button.haml["Button.haml"]
          __app__components__Form__Input.css["fab:fa-css3 Input.css&nbsp;"]
          __app__components__Form__Input.haml["Input.haml"]
          __app__components__Form__Select.css["fab:fa-css3 Select.css&nbsp;"]
          __app__components__Form__Select.haml["Select.haml"]
          __app__components__Form__Checkbox.css["fab:fa-css3 Checkbox.css&nbsp;"]
          __app__components__Form__Checkbox.haml["Checkbox.haml"]
        end
      end
      subgraph PATH__app__pages["/app/pages"]
        subgraph PATH__app__pages__docs["/app/pages/docs"]
          subgraph PATH__app__pages__docs__faq["/app/pages/docs/faq"]
            __app__pages__docs__faq__Details.css["fab:fa-css3 Details.css&nbsp;"]
            __app__pages__docs__faq__Details.haml["Details.haml"]
            __app__pages__docs__faq__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__docs__faq__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__getting-started["/app/pages/docs/getting-started"]
            __app__pages__docs__getting-started__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__docs__getting-started__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__docs__deployment["/app/pages/docs/deployment"]
            __app__pages__docs__deployment__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__docs__deployment__page.haml["page.haml"]
          end
          __app__pages__docs__layout.css["fab:fa-css3 layout.css&nbsp;"]
          __app__pages__docs__layout.haml["layout.haml"]
          __app__pages__docs__page.css["fab:fa-css3 page.css&nbsp;"]
          __app__pages__docs__page.haml["page.haml"]
          __app__pages__docs__404.css["fab:fa-css3 404.css&nbsp;"]
          __app__pages__docs__404.haml["404.haml"]
        end
        subgraph PATH__app__pages__demos["/app/pages/demos"]
          subgraph PATH__app__pages__demos__tree["/app/pages/demos/tree"]
            __app__pages__demos__tree__Directory.css["fab:fa-css3 Directory.css&nbsp;"]
            __app__pages__demos__tree__Directory.haml["Directory.haml"]
            __app__pages__demos__tree__FileEntry.css["fab:fa-css3 FileEntry.css&nbsp;"]
            __app__pages__demos__tree__FileEntry.haml["FileEntry.haml"]
            __app__pages__demos__tree__Entry.css["fab:fa-css3 Entry.css&nbsp;"]
            __app__pages__demos__tree__Entry.haml["Entry.haml"]
            __app__pages__demos__tree__FileContents.css["fab:fa-css3 FileContents.css&nbsp;"]
            __app__pages__demos__tree__FileContents.haml["FileContents.haml"]
            __app__pages__demos__tree__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__tree__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__form["/app/pages/demos/form"]
            __app__pages__demos__form__LogInForm.css["fab:fa-css3 LogInForm.css&nbsp;"]
            __app__pages__demos__form__LogInForm.haml["LogInForm.haml"]
            __app__pages__demos__form__Elements.css["fab:fa-css3 Elements.css&nbsp;"]
            __app__pages__demos__form__Elements.haml["Elements.haml"]
            __app__pages__demos__form__TransferList.css["fab:fa-css3 TransferList.css&nbsp;"]
            __app__pages__demos__form__TransferList.haml["TransferList.haml"]
            __app__pages__demos__form__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__form__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__pokemon["/app/pages/demos/pokemon"]
            subgraph PATH__app__pages__demos__pokemon__:id["/app/pages/demos/pokemon/:id"]
              __app__pages__demos__pokemon__:id__page.css["fab:fa-css3 page.css&nbsp;"]
              __app__pages__demos__pokemon__:id__page.haml["page.haml"]
            end
            __app__pages__demos__pokemon__layout.css["fab:fa-css3 layout.css&nbsp;"]
            __app__pages__demos__pokemon__layout.haml["layout.haml"]
            __app__pages__demos__pokemon__Pagination.css["fab:fa-css3 Pagination.css&nbsp;"]
            __app__pages__demos__pokemon__Pagination.haml["Pagination.haml"]
            __app__pages__demos__pokemon__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__pokemon__page.haml["page.haml"]
          end
          subgraph PATH__app__pages__demos__i18n["/app/pages/demos/i18n"]
            __app__pages__demos__i18n__page.css["fab:fa-css3 page.css&nbsp;"]
            __app__pages__demos__i18n__page.haml["page.haml"]
          end
          __app__pages__demos__layout.css["fab:fa-css3 layout.css&nbsp;"]
          __app__pages__demos__layout.haml["layout.haml"]
          __app__pages__demos__ButtonGame.css["fab:fa-css3 ButtonGame.css&nbsp;"]
          __app__pages__demos__ButtonGame.haml["ButtonGame.haml"]
          __app__pages__demos__page.css["fab:fa-css3 page.css&nbsp;"]
          __app__pages__demos__page.haml["page.haml"]
        end
        __app__pages__Intro.css["fab:fa-css3 Intro.css&nbsp;"]
        __app__pages__Intro.haml["Intro.haml"]
        __app__pages__layout.css["fab:fa-css3 layout.css&nbsp;"]
        __app__pages__layout.haml["layout.haml"]
        __app__pages__Counter.css["fab:fa-css3 Counter.css&nbsp;"]
        __app__pages__Counter.haml["Counter.haml"]
        __app__pages__FeatureThing.css["fab:fa-css3 FeatureThing.css&nbsp;"]
        __app__pages__FeatureThing.haml["FeatureThing.haml"]
        __app__pages__page.css["fab:fa-css3 page.css&nbsp;"]
        __app__pages__page.haml["page.haml"]
        __app__pages__404.css["fab:fa-css3 404.css&nbsp;"]
        __app__pages__404.haml["404.haml"]
      end
      __app__root.css["fab:fa-css3 root.css&nbsp;"]
      __app__root.haml["root.haml"]
    end
  end
  __app__root.haml-->__app__root.css
  __app__components__Layout__MaxWidth.haml-->__app__components__Layout__MaxWidth.css
  __app__components__Layout__Heading.haml-->__app__components__Layout__Heading.css
  __app__pages__Intro.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__Intro.haml-->__app__components__Layout__Heading.haml
  __app__pages__Intro.haml-->__app__pages__Intro.css
  __app__components__Layout__Header.haml-->__app__components__Layout__MaxWidth.haml
  __app__components__Layout__Header.haml-->__app__components__Layout__logo.png
  __app__components__Layout__Header.haml-->__app__components__Layout__Header.css
  __app__components__Layout__Footer.haml-->__app__components__Layout__MaxWidth.haml
  __app__components__Layout__Footer.haml-->__app__components__Layout__Footer.css
  __app__pages__layout.haml-->__app__pages__Intro.haml
  __app__pages__layout.haml-->__app__components__Layout__Header.haml
  __app__pages__layout.haml-->__app__components__Layout__Footer.haml
  __app__pages__layout.haml-->__app__pages__layout.css
  __app__pages__Counter.haml-->__app__pages__Counter.css
  __app__pages__FeatureThing.haml-->__app__pages__FeatureThing.css
  __app__pages__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__page.haml-->__app__pages__Counter.haml
  __app__pages__page.haml-->__app__pages__FeatureThing.haml
  __app__pages__page.haml-->__app__pages__page.css
  __app__components__Layout__Page.haml-->__app__components__Layout__MaxWidth.haml
  __app__components__Layout__Page.haml-->__app__components__Layout__Heading.haml
  __app__components__Layout__Page.haml-->__app__components__Layout__Page.css
  __app__components__Layout__Menu.haml-->__app__components__Layout__Menu.css
  __app__components__Layout__MenuItem.haml-->__app__components__Layout__MenuItem.css
  __app__pages__docs__layout.haml-->__app__components__Layout__Page.haml
  __app__pages__docs__layout.haml-->__app__components__Layout__Menu.haml
  __app__pages__docs__layout.haml-->__app__components__Layout__MenuItem.haml
  __app__pages__docs__layout.haml-->__app__pages__docs__layout.css
  __app__pages__docs__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__docs__page.haml-->__app__pages__docs__page.css
  __app__pages__docs__faq__Details.haml-->__app__pages__docs__faq__Details.css
  __app__pages__docs__faq__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__faq__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__docs__faq__page.haml-->__app__pages__docs__faq__Details.haml
  __app__pages__docs__faq__page.haml-->__app__pages__docs__faq__page.css
  __app__pages__docs__getting-started__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__getting-started__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__docs__getting-started__page.haml-->__app__pages__docs__getting-started__page.css
  __app__pages__docs__deployment__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__deployment__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__docs__deployment__page.haml-->__app__pages__docs__deployment__page.css
  __app__pages__docs__404.haml-->__app__components__Layout__Heading.haml
  __app__pages__docs__404.haml-->__app__pages__docs__404.css
  __app__pages__demos__layout.haml-->__app__components__Layout__Page.haml
  __app__pages__demos__layout.haml-->__app__components__Layout__Menu.haml
  __app__pages__demos__layout.haml-->__app__components__Layout__MenuItem.haml
  __app__pages__demos__layout.haml-->__app__pages__demos__layout.css
  __app__pages__demos__ButtonGame.haml-->__app__pages__demos__ButtonGame.css
  __app__pages__demos__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__demos__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__page.haml-->__app__pages__demos__ButtonGame.haml
  __app__pages__demos__page.haml-->__app__pages__demos__page.css
  __app__pages__demos__tree__Directory.haml-->__app__pages__demos__tree__Directory.css
  __app__pages__demos__tree__FileEntry.haml-->__app__pages__demos__tree__FileEntry.css
  __app__pages__demos__tree__Entry.haml-->__app__pages__demos__tree__Directory.haml
  __app__pages__demos__tree__Entry.haml-->__app__pages__demos__tree__FileEntry.haml
  __app__pages__demos__tree__Entry.haml-->__app__pages__demos__tree__Entry.css
  __app__pages__demos__tree__FileContents.haml-->__app__pages__demos__tree__FileContents.css
  __app__pages__demos__tree__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__demos__tree__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__tree__page.haml-->__app__pages__demos__tree__Entry.haml
  __app__pages__demos__tree__page.haml-->__app__pages__demos__tree__FileContents.haml
  __app__pages__demos__tree__page.haml-->__app__pages__demos__tree__page.css
  __app__components__Form__Fieldset.haml-->__app__components__Form__Fieldset.css
  __app__pages__demos__form__LogInForm.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__form__LogInForm.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__form__LogInForm.haml-->__app__pages__demos__form__LogInForm.css
  __app__components__Form__Button.haml-->__app__components__Form__Button.css
  __app__components__Form__Input.haml-->__app__components__Form__Input.css
  __app__components__Form__Select.haml-->__app__components__Form__Select.css
  __app__components__Form__Checkbox.haml-->__app__components__Form__Checkbox.css
  __app__pages__demos__form__Elements.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Button.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Input.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Select.haml
  __app__pages__demos__form__Elements.haml-->__app__components__Form__Checkbox.haml
  __app__pages__demos__form__Elements.haml-->__app__pages__demos__form__Elements.css
  __app__pages__demos__form__TransferList.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Button.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Input.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Select.haml
  __app__pages__demos__form__TransferList.haml-->__app__components__Form__Checkbox.haml
  __app__pages__demos__form__TransferList.haml-->__app__pages__demos__form__TransferList.css
  __app__pages__demos__form__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__demos__form__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__form__page.haml-->__app__pages__demos__form__LogInForm.haml
  __app__pages__demos__form__page.haml-->__app__pages__demos__form__Elements.haml
  __app__pages__demos__form__page.haml-->__app__pages__demos__form__TransferList.haml
  __app__pages__demos__form__page.haml-->__app__pages__demos__form__page.css
  __app__pages__demos__pokemon__layout.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__demos__pokemon__layout.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__pokemon__layout.haml-->__app__pages__demos__pokemon__layout.css
  __app__pages__demos__pokemon__Pagination.haml-->__app__components__Form__Fieldset.haml
  __app__pages__demos__pokemon__Pagination.haml-->__app__components__Form__Button.haml
  __app__pages__demos__pokemon__Pagination.haml-->__app__pages__demos__pokemon__Pagination.css
  __app__pages__demos__pokemon__page.haml-->__app__pages__demos__pokemon__Pagination.haml
  __app__pages__demos__pokemon__page.haml-->__app__pages__demos__pokemon__page.css
  __app__pages__demos__pokemon__:id__page.haml-->__app__pages__demos__pokemon__:id__page.css
  __app__pages__demos__i18n__page.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__demos__i18n__page.haml-->__app__components__Layout__Heading.haml
  __app__pages__demos__i18n__page.haml-->__app__pages__demos__i18n__page.css
  __app__pages__404.haml-->__app__components__Layout__MaxWidth.haml
  __app__pages__404.haml-->__app__components__Layout__Heading.haml
  __app__pages__404.haml-->__app__pages__404.css
  class __app__root.css CSS
  class __app__components__Layout__MaxWidth.css NonExistant
  class __app__components__Layout__MaxWidth.css CSS
  class __app__components__Layout__Heading.css CSS
  class __app__pages__Intro.css CSS
  class __app__components__Layout__logo.png Image
  class __app__components__Layout__Header.css CSS
  class __app__components__Layout__Footer.css NonExistant
  class __app__components__Layout__Footer.css CSS
  class __app__pages__layout.css CSS
  class __app__pages__Counter.css NonExistant
  class __app__pages__Counter.css CSS
  class __app__pages__FeatureThing.css NonExistant
  class __app__pages__FeatureThing.css CSS
  class __app__pages__page.css CSS
  class __app__components__Layout__Page.css CSS
  class __app__components__Layout__Menu.css NonExistant
  class __app__components__Layout__Menu.css CSS
  class __app__components__Layout__MenuItem.css NonExistant
  class __app__components__Layout__MenuItem.css CSS
  class __app__pages__docs__layout.css CSS
  class __app__pages__docs__page.css NonExistant
  class __app__pages__docs__page.css CSS
  class __app__pages__docs__faq__Details.css NonExistant
  class __app__pages__docs__faq__Details.css CSS
  class __app__pages__docs__faq__page.css NonExistant
  class __app__pages__docs__faq__page.css CSS
  class __app__pages__docs__getting-started__page.css NonExistant
  class __app__pages__docs__getting-started__page.css CSS
  class __app__pages__docs__deployment__page.css CSS
  class __app__pages__docs__404.css NonExistant
  class __app__pages__docs__404.css CSS
  class __app__pages__demos__layout.css NonExistant
  class __app__pages__demos__layout.css CSS
  class __app__pages__demos__ButtonGame.css NonExistant
  class __app__pages__demos__ButtonGame.css CSS
  class __app__pages__demos__page.css NonExistant
  class __app__pages__demos__page.css CSS
  class __app__pages__demos__tree__Directory.css NonExistant
  class __app__pages__demos__tree__Directory.css CSS
  class __app__pages__demos__tree__FileEntry.css NonExistant
  class __app__pages__demos__tree__FileEntry.css CSS
  class __app__pages__demos__tree__Entry.css NonExistant
  class __app__pages__demos__tree__Entry.css CSS
  class __app__pages__demos__tree__FileContents.css NonExistant
  class __app__pages__demos__tree__FileContents.css CSS
  class __app__pages__demos__tree__page.css NonExistant
  class __app__pages__demos__tree__page.css CSS
  class __app__components__Form__Fieldset.css NonExistant
  class __app__components__Form__Fieldset.css CSS
  class __app__pages__demos__form__LogInForm.css CSS
  class __app__components__Form__Button.css NonExistant
  class __app__components__Form__Button.css CSS
  class __app__components__Form__Input.css NonExistant
  class __app__components__Form__Input.css CSS
  class __app__components__Form__Select.css NonExistant
  class __app__components__Form__Select.css CSS
  class __app__components__Form__Checkbox.css NonExistant
  class __app__components__Form__Checkbox.css CSS
  class __app__pages__demos__form__Elements.css NonExistant
  class __app__pages__demos__form__Elements.css CSS
  class __app__pages__demos__form__TransferList.css CSS
  class __app__pages__demos__form__page.css CSS
  class __app__pages__demos__pokemon__layout.css NonExistant
  class __app__pages__demos__pokemon__layout.css CSS
  class __app__pages__demos__pokemon__Pagination.css CSS
  class __app__pages__demos__pokemon__page.css NonExistant
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
