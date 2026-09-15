# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "samovar"

require_relative "commands/init"
require_relative "commands/dev"
require_relative "commands/test"
require_relative "commands/build"
require_relative "commands/routes"
require_relative "commands/graph"
require_relative "commands/transform"
require_relative "commands/lsp"

module Mayu
  module Build
    # The `mayu` subcommands that need klenod-build. `Mayu::Commands` picks
    # these up when this file is loadable and shows placeholders otherwise.
    module Commands
      COMMANDS = {
        "init" => Init,
        "dev" => Dev,
        "test" => Test,
        "build" => Build,
        "routes" => Routes,
        "graph" => Graph,
        "transform" => Transform,
        "lsp" => Lsp
      }.freeze
    end
  end
end
