# frozen_string_literal: true

# Loaded once in the server's parent process. See Mayu::Setup.

require_relative "db/database"

Database.connect

Mayu.setup do |setup|
  # The production server evaluates app/models before it forks, and defining
  # a model reads its table's schema.
  setup.before_fork { Database.disconnect }

  setup.on_worker do |environment|
    environment.on_start { Database.start_listener } if Database.enabled?
  end
end
