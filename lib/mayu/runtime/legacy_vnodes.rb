# frozen_string_literal: true
#
# NOTE: Legacy VNodes implementation. Not loaded by default.
# Keep for reference only; do not require from runtime.
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "dom"
require_relative "dom_nesting_validation"
require_relative "h"
require_relative "descriptors"

require_relative "legacy_vnodes/"
require_relative "legacy_vnodes/base"
require_relative "legacy_vnodes/vany"
require_relative "legacy_vnodes/vattributes"
require_relative "legacy_vnodes/vbody"
require_relative "legacy_vnodes/vchildren"
require_relative "legacy_vnodes/vcustom_element"
require_relative "legacy_vnodes/vcomment"
require_relative "legacy_vnodes/vcomponent"
require_relative "legacy_vnodes/vdocument"
require_relative "legacy_vnodes/velement"
require_relative "legacy_vnodes/vhead"
require_relative "legacy_vnodes/vslot"
require_relative "legacy_vnodes/vstateless"
require_relative "legacy_vnodes/vtext"
