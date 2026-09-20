#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "async"
require "oga"
require "rouge"

require "mayu/runtime"
require "mayu/runtime/h"
require "mayu/runtime/dom"
require "mayu/component"

require_relative "test/query"
require_relative "test/component_handle"
require_relative "test/fake_metrics"
require_relative "test/filters"
require_relative "test/page"
require_relative "test/helpers"
require_relative "test/case"
