# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "samovar"
require "mayu/cli"

module Mayu
  module Build
    module Commands
      # The same production server `mayu start` runs without mayu-build, so
      # that a developer machine and a production image behave alike.
      class Start < Samovar::Command
        self.description = "Start the production server"

        options do
          option(
            "--filename <string>",
            "Filename of the generated bundle",
            default: Klenod::BUNDLE_FILENAME
          )
          option(
            "--assets-dir <path>",
            "Directory with the assets written by mayu build",
            default: Klenod::ASSETS_DIR
          )
          option(
            "--source-root <path>",
            "Directory the bundle was built from, for backtraces and source maps",
            default: Klenod::SOURCE_DIR
          )
        end

        def call
          Mayu::CLI.start(
            filename: options[:filename],
            assets_dir: options[:assets_dir],
            source_root: options[:source_root],
            output:
          )
        end
      end
    end
  end
end
