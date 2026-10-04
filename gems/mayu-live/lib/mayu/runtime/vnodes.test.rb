#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "vnodes/__test__/rendering.test"
require_relative "vnodes/__test__/patches.test"
require_relative "vnodes/__test__/lifecycle.test"
require_relative "vnodes/__test__/head.test"
require_relative "vnodes/__test__/callbacks.test"
require_relative "vnodes/__test__/serialization.test"
require_relative "vnodes/__test__/hot_reload.test"
require_relative "vnodes/__test__/error_boundary.test"
require_relative "vnodes/__test__/view_transitions.test"
require_relative "vnodes/__test__/slots.test"
