# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `fuzzy_match` gem.
# Please instead update this file by running `bin/tapioca gem fuzzy_match`.

# See the README for more information.
#
# source://fuzzy_match//lib/fuzzy_match/rule.rb#1
class FuzzyMatch
  # haystack - a bunch of records that will compete to see who best matches the needle
  #
  # Rules (can only be specified at initialization or by using a setter)
  # * :<tt>identities</tt> - regexps
  # * :<tt>groupings</tt> - regexps
  # * :<tt>stop_words</tt> - regexps
  # * :<tt>read</tt> - how to interpret each record in the 'haystack', either a Proc or a symbol
  #
  # Options (can be specified at initialization or when calling #find)
  # * :<tt>must_match_grouping</tt> - don't return a match unless the needle fits into one of the groupings you specified
  # * :<tt>must_match_at_least_one_word</tt> - don't return a match unless the needle shares at least one word with the match
  # * :<tt>gather_last_result</tt> - enable <tt>last_result</tt>
  # * :<tt>threshold</tt> - set a score threshold below which not to return results (not generally recommended - please test the results of setting a threshold thoroughly - one set of results and their scores probably won't be enough to determine the appropriate number). Only checked against the Pair Distance score and ignored when one string or the other is of length 1.
  #
  # @return [FuzzyMatch] a new instance of FuzzyMatch
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#68
  def initialize(haystack, options_and_rules = T.unsafe(nil)); end

  # Returns the value of attribute default_options.
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#53
  def default_options; end

  # Explain is like mysql's EXPLAIN command. You give it a needle and it tells you about how it was located (successfully or not) in the haystack.
  #
  #     d = FuzzyMatch.new ['737', '747', '757' ]
  #     d.explain 'boeing 737-100'
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#331
  def explain(needle, options = T.unsafe(nil)); end

  # source://fuzzy_match//lib/fuzzy_match.rb#114
  def find(needle, options = T.unsafe(nil)); end

  # Return everything in sorted order
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#91
  def find_all(needle, options = T.unsafe(nil)); end

  # Return everything in sorted order with score
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#103
  def find_all_with_score(needle, options = T.unsafe(nil)); end

  # Return the top results with the same score
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#97
  def find_best(needle, options = T.unsafe(nil)); end

  # Return one with score
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#109
  def find_with_score(needle, options = T.unsafe(nil)); end

  # Returns the value of attribute groupings.
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#49
  def groupings; end

  # Returns the value of attribute haystack.
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#48
  def haystack; end

  # Returns the value of attribute identities.
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#50
  def identities; end

  # source://fuzzy_match//lib/fuzzy_match.rb#86
  def last_result; end

  # Returns the value of attribute read.
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#52
  def read; end

  # Sets the attribute read
  #
  # @param value the value to set the attribute read to.
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#52
  def read=(_arg0); end

  # Returns the value of attribute stop_words.
  #
  # source://fuzzy_match//lib/fuzzy_match.rb#51
  def stop_words; end

  class << self
    # source://fuzzy_match//lib/fuzzy_match.rb#12
    def engine; end

    # source://fuzzy_match//lib/fuzzy_match.rb#16
    def engine=(alt_engine); end

    # source://fuzzy_match//lib/fuzzy_match.rb#20
    def score_class; end
  end
end

# source://fuzzy_match//lib/fuzzy_match.rb#32
FuzzyMatch::DEFAULT_ENGINE = T.let(T.unsafe(nil), Symbol)

# TODO refactor at least all the :find_X things
#
# source://fuzzy_match//lib/fuzzy_match.rb#35
FuzzyMatch::DEFAULT_OPTIONS = T.let(T.unsafe(nil), Hash)

# Records are the tokens that are passed around when doing scoring and optimizing.
#
# source://fuzzy_match//lib/fuzzy_match/record.rb#3
class FuzzyMatch::Record
  # @return [Record] a new instance of Record
  #
  # source://fuzzy_match//lib/fuzzy_match/record.rb#15
  def initialize(original, options = T.unsafe(nil)); end

  # source://fuzzy_match//lib/fuzzy_match/record.rb#25
  def clean; end

  # source://fuzzy_match//lib/fuzzy_match/record.rb#21
  def inspect; end

  # Returns the value of attribute original.
  #
  # source://fuzzy_match//lib/fuzzy_match/record.rb#11
  def original; end

  # Returns the value of attribute read.
  #
  # source://fuzzy_match//lib/fuzzy_match/record.rb#12
  def read; end

  # source://fuzzy_match//lib/fuzzy_match/record.rb#39
  def similarity(other); end

  # Returns the value of attribute stop_words.
  #
  # source://fuzzy_match//lib/fuzzy_match/record.rb#13
  def stop_words; end

  # source://fuzzy_match//lib/fuzzy_match/record.rb#43
  def whole; end

  # source://fuzzy_match//lib/fuzzy_match/record.rb#35
  def words; end
end

# source://fuzzy_match//lib/fuzzy_match/record.rb#9
FuzzyMatch::Record::BLANK = T.let(T.unsafe(nil), String)

# source://fuzzy_match//lib/fuzzy_match/record.rb#8
FuzzyMatch::Record::EMPTY = T.let(T.unsafe(nil), Array)

# "Foo's" is one word
# "North-west" is just one word
# "Bolivia," is just Bolivia
#
# source://fuzzy_match//lib/fuzzy_match/record.rb#7
FuzzyMatch::Record::WORD_BOUNDARY = T.let(T.unsafe(nil), Regexp)

# source://fuzzy_match//lib/fuzzy_match/result.rb#6
class FuzzyMatch::Result
  # @return [Result] a new instance of Result
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#37
  def initialize; end

  # source://fuzzy_match//lib/fuzzy_match/result.rb#41
  def explain; end

  # Returns the value of attribute groupings.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#30
  def groupings; end

  # Sets the attribute groupings
  #
  # @param value the value to set the attribute groupings to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#30
  def groupings=(_arg0); end

  # Returns the value of attribute haystack.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#28
  def haystack; end

  # Sets the attribute haystack
  #
  # @param value the value to set the attribute haystack to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#28
  def haystack=(_arg0); end

  # Returns the value of attribute identities.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#31
  def identities; end

  # Sets the attribute identities
  #
  # @param value the value to set the attribute identities to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#31
  def identities=(_arg0); end

  # Returns the value of attribute needle.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#26
  def needle; end

  # Sets the attribute needle
  #
  # @param value the value to set the attribute needle to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#26
  def needle=(_arg0); end

  # Returns the value of attribute options.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#29
  def options; end

  # Sets the attribute options
  #
  # @param value the value to set the attribute options to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#29
  def options=(_arg0); end

  # Returns the value of attribute read.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#27
  def read; end

  # Sets the attribute read
  #
  # @param value the value to set the attribute read to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#27
  def read=(_arg0); end

  # Returns the value of attribute score.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#34
  def score; end

  # Sets the attribute score
  #
  # @param value the value to set the attribute score to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#34
  def score=(_arg0); end

  # Returns the value of attribute stop_words.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#32
  def stop_words; end

  # Sets the attribute stop_words
  #
  # @param value the value to set the attribute stop_words to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#32
  def stop_words=(_arg0); end

  # Returns the value of attribute timeline.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#35
  def timeline; end

  # Returns the value of attribute winner.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#33
  def winner; end

  # Sets the attribute winner
  #
  # @param value the value to set the attribute winner to.
  #
  # source://fuzzy_match//lib/fuzzy_match/result.rb#33
  def winner=(_arg0); end
end

# source://fuzzy_match//lib/fuzzy_match/result.rb#7
FuzzyMatch::Result::EXPLANATION = T.let(T.unsafe(nil), String)

# A rule characterized by a regexp. Abstract.
#
# source://fuzzy_match//lib/fuzzy_match/rule.rb#3
class FuzzyMatch::Rule
  # @return [Rule] a new instance of Rule
  #
  # source://fuzzy_match//lib/fuzzy_match/rule.rb#6
  def initialize(regexp); end

  # source://fuzzy_match//lib/fuzzy_match/rule.rb#13
  def ==(other); end

  # Returns the value of attribute regexp.
  #
  # source://fuzzy_match//lib/fuzzy_match/rule.rb#4
  def regexp; end
end

# "Record linkage typically involves two main steps: grouping and scoring..."
# http://en.wikipedia.org/wiki/Record_linkage
#
# Groupings effectively divide up the haystack into groups that match a pattern
#
# A grouping (formerly known as a blocking) comes into effect when a str matches.
# Then the needle must also match the grouping's regexp.
#
# source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#11
class FuzzyMatch::Rule::Grouping < ::FuzzyMatch::Rule
  # Returns the value of attribute chain.
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#31
  def chain; end

  # Sets the attribute chain
  #
  # @param value the value to set the attribute chain to.
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#31
  def chain=(_arg0); end

  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#33
  def inspect; end

  # @return [Boolean]
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#50
  def xjoin?(needle, straw); end

  # @return [Boolean]
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#42
  def xmatch?(record); end

  protected

  # @return [Boolean]
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#77
  def join?(needle, straw); end

  # @return [Boolean]
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#73
  def match?(record); end

  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#65
  def primary; end

  # @return [Boolean]
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#60
  def primary?; end

  # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#69
  def subs; end

  class << self
    # source://fuzzy_match//lib/fuzzy_match/rule/grouping.rb#13
    def make(regexps); end
  end
end

# Identities take effect when needle and haystack both match a regexp
# Then the captured part of the regexp has to match exactly
#
# source://fuzzy_match//lib/fuzzy_match/rule/identity.rb#5
class FuzzyMatch::Rule::Identity < ::FuzzyMatch::Rule
  # @return [Identity] a new instance of Identity
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/identity.rb#8
  def initialize(regexp_or_proc); end

  # source://fuzzy_match//lib/fuzzy_match/rule/identity.rb#19
  def ==(other); end

  # Two strings are "identical" if they both match this identity and the captures are equal.
  #
  # Only returns true/false if both strings match the regexp.
  # Otherwise returns nil.
  #
  # @return [Boolean]
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/identity.rb#27
  def identical?(record1, record2); end

  # Returns the value of attribute proc.
  #
  # source://fuzzy_match//lib/fuzzy_match/rule/identity.rb#6
  def proc; end
end

# source://fuzzy_match//lib/fuzzy_match/score/pure_ruby.rb#2
class FuzzyMatch::Score
  include ::Comparable

  # @return [Score] a new instance of Score
  #
  # source://fuzzy_match//lib/fuzzy_match/score.rb#11
  def initialize(str1, str2); end

  # source://fuzzy_match//lib/fuzzy_match/score.rb#20
  def <=>(other); end

  # source://fuzzy_match//lib/fuzzy_match/score.rb#16
  def inspect; end

  # Returns the value of attribute str1.
  #
  # source://fuzzy_match//lib/fuzzy_match/score.rb#8
  def str1; end

  # Returns the value of attribute str2.
  #
  # source://fuzzy_match//lib/fuzzy_match/score.rb#9
  def str2; end
end

# be sure to `require 'amatch'` before you use this class
#
# source://fuzzy_match//lib/fuzzy_match/score/amatch.rb#4
class FuzzyMatch::Score::Amatch < ::FuzzyMatch::Score
  # source://fuzzy_match//lib/fuzzy_match/score/amatch.rb#6
  def dices_coefficient_similar; end

  # source://fuzzy_match//lib/fuzzy_match/score/amatch.rb#16
  def levenshtein_similar; end
end

# source://fuzzy_match//lib/fuzzy_match/score/pure_ruby.rb#3
class FuzzyMatch::Score::PureRuby < ::FuzzyMatch::Score
  # http://stackoverflow.com/questions/653157/a-better-similarity-ranking-algorithm-for-variable-length-strings
  #
  # source://fuzzy_match//lib/fuzzy_match/score/pure_ruby.rb#8
  def dices_coefficient_similar; end

  # extracted/adapted from the text gem version 1.0.2
  # normalization added for utf-8 strings
  # lib/text/levenshtein.rb
  #
  # source://fuzzy_match//lib/fuzzy_match/score/pure_ruby.rb#44
  def levenshtein_similar; end

  private

  # @return [Boolean]
  #
  # source://fuzzy_match//lib/fuzzy_match/score/pure_ruby.rb#88
  def utf8?; end
end

# source://fuzzy_match//lib/fuzzy_match/score/pure_ruby.rb#5
FuzzyMatch::Score::PureRuby::SPACE = T.let(T.unsafe(nil), String)

# source://fuzzy_match//lib/fuzzy_match/similarity.rb#2
class FuzzyMatch::Similarity
  # @return [Similarity] a new instance of Similarity
  #
  # source://fuzzy_match//lib/fuzzy_match/similarity.rb#6
  def initialize(record1, record2); end

  # source://fuzzy_match//lib/fuzzy_match/similarity.rb#11
  def <=>(other); end

  # source://fuzzy_match//lib/fuzzy_match/similarity.rb#20
  def best_score; end

  # source://fuzzy_match//lib/fuzzy_match/similarity.rb#30
  def inspect; end

  # Weight things towards short original strings
  #
  # source://fuzzy_match//lib/fuzzy_match/similarity.rb#35
  def original_weight; end

  # Returns the value of attribute record1.
  #
  # source://fuzzy_match//lib/fuzzy_match/similarity.rb#3
  def record1; end

  # Returns the value of attribute record2.
  #
  # source://fuzzy_match//lib/fuzzy_match/similarity.rb#4
  def record2; end

  # @return [Boolean]
  #
  # source://fuzzy_match//lib/fuzzy_match/similarity.rb#24
  def satisfy?(needle, threshold); end
end
