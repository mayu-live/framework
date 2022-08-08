require "digest/sha2"

class ClassNames
  def initialize(styles)
    @styles = styles
  end

  def classnames(*classes, **optionals)
    [classes + optionals.select { _2 }.keys]
      .flatten.compact.uniq
      .map { |klass|
        @styles.fetch(klass) {
          puts "\e[33mClass not found: #{klass}\e[0m"
        }
      }.compact.join(" ")
  end
end

styles = %i(item foo hat).map { |klass|
  classname = "#{klass}_#{Digest::SHA256.hexdigest(klass.to_s)}"
  [klass, classname]
}.to_h

puts ClassNames.new(styles).classnames(foo: true, bar: false)
