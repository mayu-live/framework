# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  NullStyleSheet =
    Data.define(:source_filename) do
      def [](*class_names)
        unless class_names.compact.all? {
                 _1.start_with?("__") || String === _1
               }
          puts "\e[1;91mNo stylesheet defined\e[0;31m (#{source_filename})\e[0m"
        end

        class_names.filter { String === _1 }
      end

      def merge(other)
        other || self
      end

      def each(&)
      end
    end

  MergedStyleSheet =
    Data.define(:stylesheets) do
      def [](*class_names)
        stylesheets.map { _1[*class_names] }.flatten.compact.uniq
      end

      def each(&)
        stylesheets.each(&)
      end
    end

  StyleSheet =
    Data.define(:source_filename, :content_hash, :classes, :content) do
      def self.encode_url(url)
        url
      end

      def filename
        source_filename + ".css"
      end

      def each(&)
        yield self
      end

      def [](*class_names)
        class_names
          .compact
          .flatten
          .map do |class_name|
            case class_name
            in String
              class_name
            in Hash
              self[*class_name.filter { _2 }.keys]
            in Symbol
              classes.fetch(class_name) do
                unless class_name.start_with?("__")
                  available_class_names =
                    classes.keys.reject { _1.start_with?("__") }.join(", ")

                  Console.logger.error(
                    source_filename,
                    format(<<~MSG, class_name, available_class_names)
                      Could not find class: \e[1;31m.%s\e[0m
                      Available class names:
                      \e[1;33m%s\e[0m
                    MSG
                  )
                  nil
                end
              end
            else
              nil
            end
          end
          .compact
          .uniq
      end

      def merge(other)
        other ? MergedStyleSheet[stylesheets: [self, other]] : self
      end
    end
end
