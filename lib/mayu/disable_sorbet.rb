# typed: false
# frozen_string_literal: true

require "sorbet-runtime"

module Mayu
  module DisableSorbet
    def self.disable_sorbet!
      # https://github.com/sorbet/sorbet/issues/3279#issuecomment-679154712
      T::Configuration.default_checked_level = :never

      error_handler =
        lambda do |error, *_|
          # Log error somewhere
        end

      # Suppresses errors caused by T.cast, T.let, T.must, etc.
      T::Configuration.inline_type_error_handler = error_handler
      # Suppresses errors caused by incorrect parameter ordering
      T::Configuration.sig_validation_error_handler = error_handler
    end
  end
end
