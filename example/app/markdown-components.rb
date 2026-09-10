# frozen_string_literal: true

MarkdownHeading = import("/components/Markdown/Heading")
MarkdownCodeBlock = import("/components/Markdown/CodeBlock")
MarkdownInlineCode = import("/components/Markdown/InlineCode")
MarkdownListItem = import("/components/Markdown/ListItem")
Link = import("/components/UI/Link")

# Klenod's Markdown compiler looks for this file and replaces matching HTML
# tags with these components. Unmapped tags continue to render as native HTML.
Default = {
  a: Link,
  code: MarkdownInlineCode,
  h1: MarkdownHeading::H1,
  h2: MarkdownHeading::H2,
  h3: MarkdownHeading::H3,
  h4: MarkdownHeading::H4,
  h5: MarkdownHeading::H5,
  h6: MarkdownHeading::H6,
  li: MarkdownListItem,
  pre: MarkdownCodeBlock
}.freeze
