# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `guard-falcon` gem.
# Please instead update this file by running `bin/tapioca gem guard-falcon`.

module Guard
  class << self
    # Asynchronously trigger changes
    #
    # Currently supported args:
    #
    #   @example Old style hash:
    #     async_queue_add(modified: ['foo'], added: ['bar'], removed: [])
    #
    #   @example New style signals with args:
    #     async_queue_add([:guard_pause, :unpaused ])
    def async_queue_add(changes); end

    def init(cmdline_options); end

    # Returns the value of attribute interactor.
    def interactor; end

    # Returns the value of attribute listener.
    def listener; end

    # Returns the value of attribute queue.
    def queue; end

    # Initializes the Guard singleton:
    #
    # * Initialize the internal Guard state;
    # * Create the interactor
    # * Select and initialize the file change listener.
    #
    # @option options
    # @option options
    # @option options
    # @option options
    # @option options
    # @option options
    # @param options [Hash] a customizable set of options
    # @return [Guard] the Guard singleton
    def setup(cmdline_options = T.unsafe(nil)); end

    # Returns the value of attribute state.
    def state; end

    private

    def _evaluate(options); end

    # TODO: remove at some point
    # TODO: not tested because collides with ongoing refactoring
    def _guardfile_deprecated_check(modified); end

    def _listener_callback; end

    # TODO: obsoleted? (move to Dsl?)
    #
    # @return [Boolean]
    def _pluginless_guardfile?; end

    def _relative_pathnames(paths); end

    # Check if any of the changes are actually watched for
    # TODO: why iterate twice? reuse this info when running tasks
    #
    # @return [Boolean]
    def _relevant_changes?(changes); end
  end
end

module Guard::Falcon
  class << self
    def new(*arguments, **options); end

    # Workaround for https://github.com/guard/guard/pull/872
    def superclass; end
  end
end

class Guard::Falcon::Plugin < ::Guard::Plugin
  # @return [Plugin] a new instance of Plugin
  def initialize(**options); end

  def container_class; end
  def container_options; end
  def endpoint; end
  def load_app; end

  # As discussed in https://github.com/guard/guard/issues/713
  def logger; end

  def reload; end
  def run_on_change(paths); end

  # @return [Boolean]
  def running?; end

  def start; end
  def stop; end

  private

  def build_endpoint; end
end

Guard::Falcon::Plugin::DEFAULT_OPTIONS = T.let(T.unsafe(nil), Hash)
Guard::VERSION = T.let(T.unsafe(nil), String)