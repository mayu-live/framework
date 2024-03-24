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
            SyntaxTree::Comment.new(
              value: "# #{to_s}",
              inline: true,
              location:
            )
          end
        end

      Pos = Data.define(:line, :column)

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
        Data.define(:input, :output, :mappings) do
          def self.parse(input, output)
            input_lines = input.each_line.to_a

            mappings =
              output
                .each_line
                .with_index(1)
                .each_with_object({}) do |(line, i), acc|
                  if curr = MatchingLine.match(i, line)
                    line_no = curr.old_line
                    column =
                      input_lines[line_no.pred].to_s.index(curr.text) || 0
                    acc[curr.new_line + 1] = Pos[line_no, column]
                  end
                end

            new(input, output, mappings)
          end

          def rewrite_backtrace(backtrace, file)
            backtrace.map do |entry|
              rewrite_backtrace_entry(entry, file, mappings)
            end
          end

          def rewrite_exception(e, file)
            e.set_backtrace(rewrite_backtrace(e.backtrace, file).first(10))
          end

          def format_exception(e, source_path)
            rewrite_exception(e, source_path)

            reset = "\e[0;48;5;52m"

            interesting_lines =
              e
                .backtrace
                .grep(/\A#{Regexp.escape(source_path)}:/)
                .map { _1.match(/:(\d+):/)[1].to_i }

            [
              "\e[1;31;47m ERROR \e[3;31;47m #{e.class.name}: #{e.message} #{reset}",
              "\e[1;34mBacktrace:#{reset}",
              e.backtrace.map do |trace|
                if match = trace.match(/\A(.*):(\d+):in `(.*)'\Z/)
                  "#{reset}\e[2mfrom #{reset}\e[1m%s:%s#{reset}\e[2m:in `#{reset}\e[1m%s#{reset}\e[2m`#{reset}" % match.captures
                else
                  "from #{trace}#{reset}"
                end
              end.join("\n"),
              "\e[1;34mSource:#{reset}",
              self.input
                .each_line
                .map
                .with_index(1) do |line, i|
                  if interesting_lines.include?(i)
                    format("\e[1;31m%3d: %s#{reset}", i, line.chomp)
                  else
                    format("%3d: %s", i, line.chomp)
                  end
                end
                .join("\n")
            ].join("\n") + "\e[0m"
          end

          private

          def rewrite_backtrace_entry(entry, file, mappings)
            re = /\A#{Regexp.escape(file)}:(\d+):(.*)/

            if match = entry.match(re)
              line_no = match[1].to_i

              if mapping = find_closest_mapping(line_no, mappings)
                return [file, mapping.line, match[2]].join(":")
              end
            end

            entry
          end

          def find_closest_mapping(line_no, mappings)
            mappings
              .select { |k, _| k <= line_no }
              .max_by(&:first)
              &.last
          end
        end
    end
  end
end
