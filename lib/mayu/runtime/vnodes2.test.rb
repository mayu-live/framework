#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "vnodes2/__test__/rendering.test"
require_relative "vnodes2/__test__/patches.test"
require_relative "vnodes2/__test__/lifecycle.test"
require_relative "vnodes2/__test__/head.test"
require_relative "vnodes2/__test__/callbacks.test"
require_relative "vnodes2/__test__/serialization.test"
require_relative "vnodes2/__test__/error_boundary.test"
require_relative "vnodes2/__test__/view_transitions.test"
require_relative "vnodes2/__test__/slots.test"
