# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "base64"

module Mayu
  module Modules
    module SourceMap
      Mark =
        Data.define(:line, :text) do
          def to_s
            "SourceMapMark:#{line}:#{Base64.urlsafe_encode64(text)}"
          end

          def to_comment(location: SyntaxTree::Location.default)
            SyntaxTree::Comment.new(value: "# #{to_s}", inline: true, location:)
          end
        end

      Position = Data.define(:line, :column)

      MatchingLine =
        Data.define(:line, :old_line, :new_line, :text) do
          def self.match(new_line, line)
            if line.match(/\A\s+# SourceMapMark:(\d+):([[:alnum:]_]+)/) in [
                 line_no,
                 text
               ]
              new(line, line_no.to_i, new_line, Base64.urlsafe_decode64(text))
            end
          end
        end

      SourceMap =
        Data.define(:input, :output, :positions) do
          def self.parse(input, output)
            input_lines = input.each_line.to_a

            positions =
              output
                .each_line
                .with_index(1)
                .each_with_object({}) do |(line, i), acc|
                  if curr = MatchingLine.match(i, line)
                    line_no = curr.old_line
                    column =
                      input_lines[line_no.pred].to_s.index(curr.text) || 0
                    acc[curr.new_line + 1] = Position[line_no, column]
                  end
                end

            new(input, output, positions)
          end

          def find_original_line_no(line_no)
            positions.select { |k, _| k <= line_no }.max_by(&:first)&.last&.line
          end
        end
    end
  end
end
