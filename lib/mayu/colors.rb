# typed: strict
# frozen_string_literal: true

module Mayu
  module Colors
    extend T::Sig

    sig { params(str: String, t: Float).returns(String) }
    def self.rainbow(str, t = Time.now.to_f)
      str
        .each_line
        .map do |line|
          line
            .chars
            .map
            .with_index do |ch, i|
              next ch if ch.strip.empty?

              r, g, b =
                3
                  .times
                  .map { _1 / 3.0 * Math::PI }
                  .map { _1 + i / 10.0 }
                  .map { Math.sin(_1 - t)**2 }
                  .map { (_1 * 255).to_i }

              format("\e[38;2;%d;%d;%dm%s", r, g, b, ch)
            end
            .join
        end
        .join + "\e[0m"
    end
  end
end
