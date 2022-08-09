require "digest/sha2"

class ClassNames
  def initialize(styles)
    @styles = styles
  end

  def classnames(*classes, **optionals)
    [classes + optionals.select { _2 }.keys].flatten
      .compact
      .uniq
      .map do |klass|
        @styles.fetch(klass) { puts "\e[33mClass not found: #{klass}\e[0m" }
      end
      .compact
      .join(" ")
  end
end

styles =
  %i[item foo hat]
    .map do |klass|
      classname = "#{klass}_#{Digest::SHA256.hexdigest(klass.to_s)}"
      [klass, classname]
    end
    .to_h

puts ClassNames.new(styles).classnames(foo: true, bar: false)
