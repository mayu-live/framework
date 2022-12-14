# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `async-container` gem.
# Please instead update this file by running `bin/tapioca gem async-container`.

# source://async-container//lib/async/container/error.rb#23
module Async; end

# source://async-container//lib/async/container/error.rb#24
module Async::Container
  class << self
    # Determins the best container class based on the underlying Ruby implementation.
    # Some platforms, including JRuby, don't support fork. Applications which just want a reasonable default can use this method.
    #
    # source://async-container//lib/async/container/best.rb#38
    def best_container_class; end

    # Whether the underlying process supports fork.
    #
    # @return [Boolean]
    #
    # source://async-container//lib/async/container/best.rb#31
    def fork?; end

    # Create an instance of the best container class.
    #
    # source://async-container//lib/async/container/best.rb#48
    def new(*arguments, **options); end

    # The processor count which may be used for the default number of container threads/processes. You can override the value provided by the system by specifying the `ASYNC_CONTAINER_PROCESSOR_COUNT` environment variable.
    #
    # source://async-container//lib/async/container/generic.rb#39
    def processor_count(env = T.unsafe(nil)); end
  end
end

# An environment variable key to override {.processor_count}.
#
# source://async-container//lib/async/container/generic.rb#34
Async::Container::ASYNC_CONTAINER_PROCESSOR_COUNT = T.let(T.unsafe(nil), String)

# Provides a basic multi-thread/multi-process uni-directional communication channel.
#
# source://async-container//lib/async/container/channel.rb#28
class Async::Container::Channel
  # Initialize the channel using a pipe.
  #
  # @return [Channel] a new instance of Channel
  #
  # source://async-container//lib/async/container/channel.rb#30
  def initialize; end

  # Close both ends of the pipe.
  #
  # source://async-container//lib/async/container/channel.rb#53
  def close; end

  # Close the input end of the pipe.
  #
  # source://async-container//lib/async/container/channel.rb#43
  def close_read; end

  # Close the output end of the pipe.
  #
  # source://async-container//lib/async/container/channel.rb#48
  def close_write; end

  # The input end of the pipe.
  #
  # source://async-container//lib/async/container/channel.rb#36
  def in; end

  # The output end of the pipe.
  #
  # source://async-container//lib/async/container/channel.rb#40
  def out; end

  # Receive an object from the pipe.
  # Internally, prefers to receive newline formatted JSON, otherwise returns a hash table with a single key `:line` which contains the line of data that could not be parsed as JSON.
  #
  # source://async-container//lib/async/container/channel.rb#61
  def receive; end
end

# Manages the life-cycle of one or more containers in order to support a persistent system.
# e.g. a web server, job server or some other long running system.
#
# source://async-container//lib/async/container/controller.rb#33
class Async::Container::Controller
  # Initialize the controller.
  #
  # @return [Controller] a new instance of Controller
  #
  # source://async-container//lib/async/container/controller.rb#42
  def initialize(notify: T.unsafe(nil)); end

  # The current container being managed by the controller.
  #
  # source://async-container//lib/async/container/controller.rb#80
  def container; end

  # Create a container for the controller.
  # Can be overridden by a sub-class.
  #
  # source://async-container//lib/async/container/controller.rb#85
  def create_container; end

  # Reload the existing container. Children instances will be reloaded using `SIGHUP`.
  #
  # source://async-container//lib/async/container/controller.rb#168
  def reload; end

  # Restart the container. A new container is created, and if successful, any old container is terminated gracefully.
  #
  # source://async-container//lib/async/container/controller.rb#121
  def restart; end

  # Enter the controller run loop, trapping `SIGINT` and `SIGTERM`.
  #
  # source://async-container//lib/async/container/controller.rb#194
  def run; end

  # Whether the controller has a running container.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/controller.rb#91
  def running?; end

  # Spawn container instances into the given container.
  # Should be overridden by a sub-class.
  #
  # source://async-container//lib/async/container/controller.rb#103
  def setup(container); end

  # Start the container unless it's already running.
  #
  # source://async-container//lib/async/container/controller.rb#109
  def start; end

  # The state of the controller.
  #
  # source://async-container//lib/async/container/controller.rb#58
  def state_string; end

  # Stop the container if it's running.
  #
  # source://async-container//lib/async/container/controller.rb#115
  def stop(graceful = T.unsafe(nil)); end

  # A human readable representation of the controller.
  #
  # source://async-container//lib/async/container/controller.rb#68
  def to_s; end

  # Trap the specified signal.
  #
  # source://async-container//lib/async/container/controller.rb#75
  def trap(signal, &block); end

  # Wait for the underlying container to start.
  #
  # source://async-container//lib/async/container/controller.rb#96
  def wait; end
end

# source://async-container//lib/async/container/controller.rb#34
Async::Container::Controller::SIGHUP = T.let(T.unsafe(nil), Integer)

# source://async-container//lib/async/container/controller.rb#35
Async::Container::Controller::SIGINT = T.let(T.unsafe(nil), Integer)

# source://async-container//lib/async/container/controller.rb#36
Async::Container::Controller::SIGTERM = T.let(T.unsafe(nil), Integer)

# source://async-container//lib/async/container/controller.rb#37
Async::Container::Controller::SIGUSR1 = T.let(T.unsafe(nil), Integer)

# source://async-container//lib/async/container/controller.rb#38
Async::Container::Controller::SIGUSR2 = T.let(T.unsafe(nil), Integer)

# source://async-container//lib/async/container/error.rb#25
class Async::Container::Error < ::StandardError; end

# A multi-process container which uses {Process.fork}.
#
# source://async-container//lib/async/container/forked.rb#30
class Async::Container::Forked < ::Async::Container::Generic
  # Start a named child process and execute the provided block in it.
  #
  # source://async-container//lib/async/container/forked.rb#38
  def start(name, &block); end

  class << self
    # Indicates that this is a multi-process container.
    #
    # @return [Boolean]
    #
    # source://async-container//lib/async/container/forked.rb#31
    def multiprocess?; end
  end
end

# A base class for implementing containers.
#
# source://async-container//lib/async/container/generic.rb#52
class Async::Container::Generic
  # @return [Generic] a new instance of Generic
  #
  # source://async-container//lib/async/container/generic.rb#59
  def initialize(**options); end

  # Look up a child process by key.
  # A key could be a symbol, a file path, or something else which the child instance represents.
  #
  # source://async-container//lib/async/container/generic.rb#79
  def [](key); end

  # @deprecated Please use {spawn} or {run} instead.
  #
  # source://async-container//lib/async/container/generic.rb#209
  def async(**options, &block); end

  # Whether any failures have occurred within the container.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/generic.rb#89
  def failed?; end

  # Whether a child instance exists for the given key.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/generic.rb#244
  def key?(key); end

  # Mark the container's keyed instance which ensures that it won't be discarded.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/generic.rb#231
  def mark?(key); end

  # Reload the container's keyed instances.
  #
  # source://async-container//lib/async/container/generic.rb#216
  def reload; end

  # Run multiple instances of the same block in the container.
  #
  # source://async-container//lib/async/container/generic.rb#200
  def run(count: T.unsafe(nil), **options, &block); end

  # Whether the container has running children instances.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/generic.rb#94
  def running?; end

  # Sleep until some state change occurs.
  #
  # source://async-container//lib/async/container/generic.rb#100
  def sleep(duration = T.unsafe(nil)); end

  # Spawn a child instance into the container.
  #
  # source://async-container//lib/async/container/generic.rb#154
  def spawn(name: T.unsafe(nil), restart: T.unsafe(nil), key: T.unsafe(nil), &block); end

  # Returns the value of attribute state.
  #
  # source://async-container//lib/async/container/generic.rb#69
  def state; end

  # Statistics relating to the behavior of children instances.
  #
  # source://async-container//lib/async/container/generic.rb#85
  def statistics; end

  # Returns true if all children instances have the specified status flag set.
  # e.g. `:ready`.
  # This state is updated by the process readiness protocol mechanism. See {Notify::Client} for more details.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/generic.rb#113
  def status?(flag); end

  # Stop the children instances.
  #
  # source://async-container//lib/async/container/generic.rb#139
  def stop(timeout = T.unsafe(nil)); end

  # A human readable representation of the container.
  #
  # source://async-container//lib/async/container/generic.rb#73
  def to_s; end

  # Wait until all spawned tasks are completed.
  #
  # source://async-container//lib/async/container/generic.rb#105
  def wait; end

  # Wait until all the children instances have indicated that they are ready.
  #
  # source://async-container//lib/async/container/generic.rb#120
  def wait_until_ready; end

  protected

  # Clear the child (value) as running.
  #
  # source://async-container//lib/async/container/generic.rb#266
  def delete(key, child); end

  # Register the child (value) as running.
  #
  # source://async-container//lib/async/container/generic.rb#253
  def insert(key, child); end

  private

  # source://async-container//lib/async/container/generic.rb#277
  def fiber(&block); end

  class << self
    # source://async-container//lib/async/container/generic.rb#53
    def run(*arguments, **options, &block); end
  end
end

# source://async-container//lib/async/container/generic.rb#57
Async::Container::Generic::UNNAMED = T.let(T.unsafe(nil), String)

# Manages a group of running processes.
#
# source://async-container//lib/async/container/group.rb#31
class Async::Container::Group
  # Initialize an empty group.
  #
  # @return [Group] a new instance of Group
  #
  # source://async-container//lib/async/container/group.rb#33
  def initialize; end

  # Whether the group contains any running processes.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/group.rb#51
  def any?; end

  # Whether the group is empty.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/group.rb#57
  def empty?; end

  # Interrupt all running processes.
  # This resumes the controlling fiber with an instance of {Interrupt}.
  #
  # source://async-container//lib/async/container/group.rb#80
  def interrupt; end

  # Returns the value of attribute running.
  #
  # source://async-container//lib/async/container/group.rb#41
  def running; end

  # Whether the group contains any running processes.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/group.rb#45
  def running?; end

  # Sleep for at most the specified duration until some state change occurs.
  #
  # source://async-container//lib/async/container/group.rb#62
  def sleep(duration); end

  # Stop all child processes using {#terminate}.
  #
  # source://async-container//lib/async/container/group.rb#98
  def stop(timeout = T.unsafe(nil)); end

  # Terminate all running processes.
  # This resumes the controlling fiber with an instance of {Terminate}.
  #
  # source://async-container//lib/async/container/group.rb#89
  def terminate; end

  # Begin any outstanding queued processes and wait for them indefinitely.
  #
  # source://async-container//lib/async/container/group.rb#70
  def wait; end

  # Wait for a message in the specified {Channel}.
  #
  # source://async-container//lib/async/container/group.rb#128
  def wait_for(channel); end

  protected

  # source://async-container//lib/async/container/group.rb#176
  def resume; end

  # source://async-container//lib/async/container/group.rb#172
  def suspend; end

  # source://async-container//lib/async/container/group.rb#152
  def wait_for_children(duration = T.unsafe(nil)); end

  # source://async-container//lib/async/container/group.rb#163
  def yield; end
end

# source://async-container//lib/async/container/error.rb#39
class Async::Container::Hangup < ::SignalException
  # @return [Hangup] a new instance of Hangup
  #
  # source://async-container//lib/async/container/error.rb#42
  def initialize; end
end

# source://async-container//lib/async/container/error.rb#40
Async::Container::Hangup::SIGHUP = T.let(T.unsafe(nil), Integer)

# Provides a hybrid multi-process multi-thread container.
#
# source://async-container//lib/async/container/hybrid.rb#33
class Async::Container::Hybrid < ::Async::Container::Forked
  # Run multiple instances of the same block in the container.
  #
  # source://async-container//lib/async/container/hybrid.rb#34
  def run(count: T.unsafe(nil), forks: T.unsafe(nil), threads: T.unsafe(nil), **options, &block); end
end

# source://async-container//lib/async/container/error.rb#28
Async::Container::Interrupt = Interrupt

# Tracks a key/value pair such that unmarked keys can be identified and cleaned up.
# This helps implement persistent processes that start up child processes per directory or configuration file. If those directories and/or configuration files are removed, the child process can then be cleaned up automatically, because those key/value pairs will not be marked when reloading the container.
#
# source://async-container//lib/async/container/keyed.rb#27
class Async::Container::Keyed
  # @return [Keyed] a new instance of Keyed
  #
  # source://async-container//lib/async/container/keyed.rb#28
  def initialize(key, value); end

  # Clear the instance. This is normally done before reloading a container.
  #
  # source://async-container//lib/async/container/keyed.rb#54
  def clear!; end

  # The key. Normally a symbol or a file-system path.
  #
  # source://async-container//lib/async/container/keyed.rb#36
  def key; end

  # Mark the instance. This will indiciate that the value is still in use/active.
  #
  # source://async-container//lib/async/container/keyed.rb#49
  def mark!; end

  # Has the instance been marked?
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/keyed.rb#44
  def marked?; end

  # Stop the instance if it was not marked.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/keyed.rb#59
  def stop?; end

  # The value. Normally a child instance of some sort.
  #
  # source://async-container//lib/async/container/keyed.rb#40
  def value; end
end

# Handles the details of several process readiness protocols.
#
# source://async-container//lib/async/container/notify/client.rb#26
module Async::Container::Notify
  class << self
    # Select the best available notification client.
    # We cache the client on a per-process basis. Because that's the relevant scope for process readiness protocols.
    #
    # source://async-container//lib/async/container/notify.rb#34
    def open!; end
  end
end

# source://async-container//lib/async/container/notify/client.rb#27
class Async::Container::Notify::Client
  # Notify the parent controller of an error condition.
  #
  # source://async-container//lib/async/container/notify/client.rb#71
  def error!(text, **message); end

  # Notify the parent controller that the child has become ready, with a brief status message.
  #
  # source://async-container//lib/async/container/notify/client.rb#30
  def ready!(**message); end

  # Notify the parent controller that the child is reloading.
  #
  # source://async-container//lib/async/container/notify/client.rb#36
  def reloading!(**message); end

  # Notify the parent controller that the child is restarting.
  #
  # source://async-container//lib/async/container/notify/client.rb#46
  def restarting!(**message); end

  # Notify the parent controller of a status change.
  #
  # source://async-container//lib/async/container/notify/client.rb#64
  def status!(text); end

  # Notify the parent controller that the child is stopping.
  #
  # source://async-container//lib/async/container/notify/client.rb#56
  def stopping!(**message); end
end

# Implements a general process readiness protocol with output to the local console.
#
# source://async-container//lib/async/container/notify/console.rb#32
class Async::Container::Notify::Console < ::Async::Container::Notify::Client
  # Initialize the notification client.
  #
  # @return [Console] a new instance of Console
  #
  # source://async-container//lib/async/container/notify/console.rb#39
  def initialize(logger); end

  # Send an error message to the console.
  #
  # source://async-container//lib/async/container/notify/console.rb#51
  def error!(text, **message); end

  # Send a message to the console.
  #
  # source://async-container//lib/async/container/notify/console.rb#44
  def send(level: T.unsafe(nil), **message); end

  class << self
    # Open a notification client attached to the current console.
    #
    # source://async-container//lib/async/container/notify/console.rb#33
    def open!(logger = T.unsafe(nil)); end
  end
end

# Implements a process readiness protocol using an inherited pipe file descriptor.
#
# source://async-container//lib/async/container/notify/pipe.rb#32
class Async::Container::Notify::Pipe < ::Async::Container::Notify::Client
  # Initialize the notification client.
  #
  # @return [Pipe] a new instance of Pipe
  #
  # source://async-container//lib/async/container/notify/pipe.rb#48
  def initialize(io); end

  # Inserts or duplicates the environment given an argument array.
  # Sets or clears it in a way that is suitable for {::Process.spawn}.
  #
  # source://async-container//lib/async/container/notify/pipe.rb#54
  def before_spawn(arguments, options); end

  # Formats the message using JSON and sends it to the parent controller.
  # This is suitable for use with {Channel}.
  #
  # source://async-container//lib/async/container/notify/pipe.rb#81
  def send(**message); end

  private

  # source://async-container//lib/async/container/notify/pipe.rb#90
  def environment_for(arguments); end

  class << self
    # Open a notification client attached to the current {NOTIFY_PIPE} if possible.
    #
    # source://async-container//lib/async/container/notify/pipe.rb#36
    def open!(environment = T.unsafe(nil)); end
  end
end

# The environment variable key which contains the pipe file descriptor.
#
# source://async-container//lib/async/container/notify/pipe.rb#33
Async::Container::Notify::Pipe::NOTIFY_PIPE = T.let(T.unsafe(nil), String)

# Implements the systemd NOTIFY_SOCKET process readiness protocol.
# See <https://www.freedesktop.org/software/systemd/man/sd_notify.html> for more details of the underlying protocol.
#
# source://async-container//lib/async/container/notify/socket.rb#35
class Async::Container::Notify::Socket < ::Async::Container::Notify::Client
  # Initialize the notification client.
  #
  # @return [Socket] a new instance of Socket
  #
  # source://async-container//lib/async/container/notify/socket.rb#50
  def initialize(path); end

  # Dump a message in the format requied by `sd_notify`.
  #
  # source://async-container//lib/async/container/notify/socket.rb#57
  def dump(message); end

  # Send the specified error.
  # `sd_notify` requires an `errno` key, which defaults to `-1` to indicate a generic error.
  #
  # source://async-container//lib/async/container/notify/socket.rb#92
  def error!(text, **message); end

  # Send the given message.
  #
  # source://async-container//lib/async/container/notify/socket.rb#76
  def send(**message); end

  class << self
    # Open a notification client attached to the current {NOTIFY_SOCKET} if possible.
    #
    # source://async-container//lib/async/container/notify/socket.rb#42
    def open!(environment = T.unsafe(nil)); end
  end
end

# The maximum allowed size of the UDP message.
#
# source://async-container//lib/async/container/notify/socket.rb#39
Async::Container::Notify::Socket::MAXIMUM_MESSAGE_SIZE = T.let(T.unsafe(nil), Integer)

# The name of the environment variable which contains the path to the notification socket.
#
# source://async-container//lib/async/container/notify/socket.rb#36
Async::Container::Notify::Socket::NOTIFY_SOCKET = T.let(T.unsafe(nil), String)

# Represents a running child process from the point of view of the parent container.
#
# source://async-container//lib/async/container/process.rb#32
class Async::Container::Process < ::Async::Container::Channel
  # Initialize the process.
  #
  # @return [Process] a new instance of Process
  #
  # source://async-container//lib/async/container/process.rb#114
  def initialize(name: T.unsafe(nil)); end

  # Invoke {#terminate!} and then {#wait} for the child process to exit.
  #
  # source://async-container//lib/async/container/process.rb#147
  def close; end

  # Send `SIGINT` to the child process.
  #
  # source://async-container//lib/async/container/process.rb#155
  def interrupt!; end

  # The name of the process.
  #
  # source://async-container//lib/async/container/process.rb#138
  def name; end

  # Set the name of the process.
  # Invokes {::Process.setproctitle} if invoked in the child process.
  #
  # source://async-container//lib/async/container/process.rb#129
  def name=(value); end

  # Send `SIGTERM` to the child process.
  #
  # source://async-container//lib/async/container/process.rb#162
  def terminate!; end

  # A human readable representation of the process.
  #
  # source://async-container//lib/async/container/process.rb#142
  def to_s; end

  # Wait for the child process to exit.
  #
  # source://async-container//lib/async/container/process.rb#170
  def wait; end

  class << self
    # Fork a child process appropriate for a container.
    #
    # source://async-container//lib/async/container/process.rb#83
    def fork(**options); end
  end
end

# Represents a running child process from the point of view of the child process.
#
# source://async-container//lib/async/container/process.rb#35
class Async::Container::Process::Instance < ::Async::Container::Notify::Pipe
  # @return [Instance] a new instance of Instance
  #
  # source://async-container//lib/async/container/process.rb#47
  def initialize(io); end

  # Replace the current child process with a different one. Forwards arguments and options to {::Process.exec}.
  # This method replaces the child process with the new executable, thus this method never returns.
  #
  # source://async-container//lib/async/container/process.rb#69
  def exec(*arguments, ready: T.unsafe(nil), **options); end

  # The name of the process.
  #
  # source://async-container//lib/async/container/process.rb#63
  def name; end

  # Set the process title to the specified value.
  #
  # source://async-container//lib/async/container/process.rb#55
  def name=(value); end

  class << self
    # Wrap an instance around the {Process} instance from within the forked child.
    #
    # source://async-container//lib/async/container/process.rb#36
    def for(process); end
  end
end

# Represents the error which occured when a container failed to start up correctly.
#
# source://async-container//lib/async/container/error.rb#48
class Async::Container::SetupError < ::Async::Container::Error
  # @return [SetupError] a new instance of SetupError
  #
  # source://async-container//lib/async/container/error.rb#49
  def initialize(container); end

  # The container that failed.
  #
  # source://async-container//lib/async/container/error.rb#56
  def container; end
end

# Tracks various statistics relating to child instances in a container.
#
# source://async-container//lib/async/container/statistics.rb#28
class Async::Container::Statistics
  # @return [Statistics] a new instance of Statistics
  #
  # source://async-container//lib/async/container/statistics.rb#29
  def initialize; end

  # Append another statistics instance into this one.
  #
  # source://async-container//lib/async/container/statistics.rb#70
  def <<(other); end

  # Whether there have been any failures.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/statistics.rb#64
  def failed?; end

  # Increment the number of failures by 1.
  #
  # source://async-container//lib/async/container/statistics.rb#58
  def failure!; end

  # How many child instances have failed.
  #
  # source://async-container//lib/async/container/statistics.rb#45
  def failures; end

  # Increment the number of restarts by 1.
  #
  # source://async-container//lib/async/container/statistics.rb#53
  def restart!; end

  # How many child instances have been restarted.
  #
  # source://async-container//lib/async/container/statistics.rb#41
  def restarts; end

  # Increment the number of spawns by 1.
  #
  # source://async-container//lib/async/container/statistics.rb#48
  def spawn!; end

  # How many child instances have been spawned.
  #
  # source://async-container//lib/async/container/statistics.rb#37
  def spawns; end
end

# Similar to {Interrupt}, but represents `SIGTERM`.
#
# source://async-container//lib/async/container/error.rb#31
class Async::Container::Terminate < ::SignalException
  # @return [Terminate] a new instance of Terminate
  #
  # source://async-container//lib/async/container/error.rb#34
  def initialize; end
end

# source://async-container//lib/async/container/error.rb#32
Async::Container::Terminate::SIGTERM = T.let(T.unsafe(nil), Integer)

# Represents a running child thread from the point of view of the parent container.
#
# source://async-container//lib/async/container/thread.rb#31
class Async::Container::Thread < ::Async::Container::Channel
  # Initialize the thread.
  #
  # @return [Thread] a new instance of Thread
  #
  # source://async-container//lib/async/container/thread.rb#111
  def initialize(name: T.unsafe(nil)); end

  # Invoke {#terminate!} and then {#wait} for the child thread to exit.
  #
  # source://async-container//lib/async/container/thread.rb#155
  def close; end

  # Raise {Interrupt} in the child thread.
  #
  # source://async-container//lib/async/container/thread.rb#163
  def interrupt!; end

  # Get the name of the thread.
  #
  # source://async-container//lib/async/container/thread.rb#144
  def name; end

  # Set the name of the thread.
  #
  # source://async-container//lib/async/container/thread.rb#138
  def name=(value); end

  # Raise {Terminate} in the child thread.
  #
  # source://async-container//lib/async/container/thread.rb#168
  def terminate!; end

  # A human readable representation of the thread.
  #
  # source://async-container//lib/async/container/thread.rb#150
  def to_s; end

  # Wait for the thread to exit and return he exit status.
  #
  # source://async-container//lib/async/container/thread.rb#174
  def wait; end

  protected

  # Invoked by the @waiter thread to indicate the outcome of the child thread.
  #
  # source://async-container//lib/async/container/thread.rb#206
  def finished(error = T.unsafe(nil)); end

  class << self
    # source://async-container//lib/async/container/thread.rb#101
    def fork(**options); end
  end
end

# Used to propagate the exit status of a child process invoked by {Instance#exec}.
#
# source://async-container//lib/async/container/thread.rb#34
class Async::Container::Thread::Exit < ::Exception
  # Initialize the exit status.
  #
  # @return [Exit] a new instance of Exit
  #
  # source://async-container//lib/async/container/thread.rb#35
  def initialize(status); end

  # The process exit status if it was an error.
  #
  # source://async-container//lib/async/container/thread.rb#45
  def error; end

  # The process exit status.
  #
  # source://async-container//lib/async/container/thread.rb#41
  def status; end
end

# Represents a running child thread from the point of view of the child thread.
#
# source://async-container//lib/async/container/thread.rb#55
class Async::Container::Thread::Instance < ::Async::Container::Notify::Pipe
  # @return [Instance] a new instance of Instance
  #
  # source://async-container//lib/async/container/thread.rb#62
  def initialize(io); end

  # Execute a child process using {::Process.spawn}. In order to simulate {::Process.exec}, an {Exit} instance is raised to propagage exit status.
  # This creates the illusion that this method does not return (normally).
  #
  # source://async-container//lib/async/container/thread.rb#83
  def exec(*arguments, ready: T.unsafe(nil), **options); end

  # Get the name of the thread.
  #
  # source://async-container//lib/async/container/thread.rb#77
  def name; end

  # Set the name of the thread.
  #
  # source://async-container//lib/async/container/thread.rb#71
  def name=(value); end

  class << self
    # Wrap an instance around the {Thread} instance from within the threaded child.
    #
    # source://async-container//lib/async/container/thread.rb#56
    def for(thread); end
  end
end

# A pseudo exit-status wrapper.
#
# source://async-container//lib/async/container/thread.rb#184
class Async::Container::Thread::Status
  # Initialise the status.
  #
  # @return [Status] a new instance of Status
  #
  # source://async-container//lib/async/container/thread.rb#187
  def initialize(error = T.unsafe(nil)); end

  # Whether the status represents a successful outcome.
  #
  # @return [Boolean]
  #
  # source://async-container//lib/async/container/thread.rb#193
  def success?; end

  # A human readable representation of the status.
  #
  # source://async-container//lib/async/container/thread.rb#198
  def to_s; end
end

# A multi-thread container which uses {Thread.fork}.
#
# source://async-container//lib/async/container/threaded.rb#30
class Async::Container::Threaded < ::Async::Container::Generic
  # Start a named child thread and execute the provided block in it.
  #
  # source://async-container//lib/async/container/threaded.rb#38
  def start(name, &block); end

  class << self
    # Indicates that this is not a multi-process container.
    #
    # @return [Boolean]
    #
    # source://async-container//lib/async/container/threaded.rb#31
    def multiprocess?; end
  end
end

# source://async/2.0.3/lib/async/version.rb#24
Async::VERSION = T.let(T.unsafe(nil), String)
