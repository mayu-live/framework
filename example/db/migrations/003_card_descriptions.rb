# frozen_string_literal: true

# Timestamps were stored without a time zone, in the session's time zone,
# which is UTC. With timestamptz Sequel reads them as the right moment, so the
# pages can show them in the visitor's own time zone.
timestamps = {
  boards: :created_at,
  activities: :created_at,
  cards: :updated_at,
  todos: :created_at
}.freeze

Sequel.migration do
  up do
    alter_table(:cards) do
      add_column :description, String, text: true, null: false, default: ""
    end

    timestamps.each do |table, column|
      alter_table(table) do
        set_column_type column, :timestamptz, using: Sequel.lit("#{column} AT TIME ZONE 'UTC'")
      end
    end
  end

  down do
    timestamps.each do |table, column|
      alter_table(table) do
        set_column_type column, :timestamp, using: Sequel.lit("#{column} AT TIME ZONE 'UTC'")
      end
    end

    alter_table(:cards) do
      drop_column :description
    end
  end
end
