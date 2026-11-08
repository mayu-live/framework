# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module Component
    # Actions that run in the visitor's browser, available to components as
    # `browser`. Each action reaches the browser after the DOM updates that
    # were queued before it.
    class Browser
      def initialize(action)
        @action = action
      end

      # Navigates like a link click, so the route is resolved again with the
      # new $query and $params. Relative hrefs such as "?page=2" resolve
      # against the current URL. `replace: true` replaces the current history
      # entry instead of adding one. `document: true` requests a new document,
      # allowing HTTP handlers, redirects and cookies to take effect.
      def navigate(href, replace: false, document: false)
        unless href.is_a?(String)
          raise ArgumentError, "Expected href to be a String, got #{href.class}"
        end

        args = [href, replace ? true : false]
        args << true if document
        @action.call("navigate", args)
      end

      def alert(message)
        @action.call("alert", [message.to_s])
      end

      # Requests a full document reload in other Mayu tabs on the same origin.
      # The sending tab continues normally. Delivery is best effort.
      def reload_other_tabs
        @action.call("reload_other_tabs", [])
      end
    end
  end
end
