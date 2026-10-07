# frozen_string_literal: true

require "console"
require "sequel"
require_relative "listener"

# Connects the models in app/models to Postgres. Postgres is optional: without
# DATABASE_URL the models are defined against a mock database, so the app
# still boots, and `enabled?` tells pages to explain how to set it up.
module Database
  MIGRATIONS_DIR = File.expand_path("migrations", __dir__)

  class << self
    attr_reader :db

    def url
      url = ENV["DATABASE_URL"]
      url unless url.nil? || url.empty?
    end

    def enabled?
      !url.nil?
    end

    # Sets Sequel::Model.db. Runs in the server's parent process: the
    # production server evaluates app/models there before it forks, which is
    # why `test: false` keeps it from connecting until something needs to.
    def connect
      Sequel.extension :fiber_concurrency, :migration

      # On macOS, libpq probing for GSSAPI encryption in a forked worker
      # crashes it with "initialize may have been in progress in another
      # thread when fork() was called".
      ENV["PGGSSENCMODE"] ||= "disable" if RUBY_PLATFORM.include?("darwin")

      @db =
        if enabled?
          Sequel.connect(
            url,
            max_connections: Integer(ENV.fetch("DATABASE_POOL", "5")),
            test: false
          )
        else
          Sequel.mock(host: "postgres")
        end

      Sequel::Model.db = @db
    end

    # Forked workers must not share the parent's connections.
    def disconnect
      @db&.disconnect
    end

    # Runs in each worker. Returns the listener, whose `stop` also closes the
    # worker's connections.
    def start_listener
      unless Sequel::Migrator.is_current?(@db, MIGRATIONS_DIR)
        Console.logger.warn(self, "The database has pending migrations. Run bin/db migrate.")
      end

      @listener = Listener.start(url, on_stop: -> { disconnect })
    end

    # Calls the block with the payload of every NOTIFY on `channel` until the
    # calling task stops. Call it from `mount`.
    def listen(channel, &)
      raise "Database.listen needs DATABASE_URL" unless @listener

      @listener.subscribe(channel, &)
    end
  end
end
