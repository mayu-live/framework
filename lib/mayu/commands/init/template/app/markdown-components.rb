# frozen_string_literal: true

# Klenod uses this map for imported Markdown files and Haml :markdown filters.
# Import a component and assign it to an HTML tag when you want custom rendering:
#
# Heading = import("/components/Heading")
# Default = {h1: Heading}.freeze
#
# Unmapped tags render as semantic native HTML elements.
Default = {}.freeze
