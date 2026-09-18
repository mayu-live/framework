# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "console/event/generic"

module Mayu
  class Server
    # A service announcing where it listens, as a Console event: the HTTP
    # server, the metrics server and the metrics collector socket. Console::
    # Terminal::Formatter::MayuListen (listen_event_formatter.rb) draws it as
    # one line with the address highlighted, and the JSON output writes
    # #to_hash as it is.
    class ListenEvent < Console::Event::Generic
      TYPE = :"mayu.listen"

      SERVICES = {
        server: "server",
        metrics: "metrics server",
        collector: "metrics collection"
      }.freeze

      attr_reader :service, :url

      def initialize(service, url:)
        unless SERVICES.key?(service)
          raise ArgumentError, "unknown listening service: #{service.inspect}"
        end

        @service = service
        @url = url.to_s
      end

      def to_hash
        {type: TYPE, service: @service, url: @url}
      end
    end
  end
end
