# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:boards) do
      primary_key :id
      String :name, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    # Positions are unique per parent. The constraints are deferred so a move
    # can shift positions within a transaction and only has to be consistent
    # when it commits.
    create_table(:kanban_columns) do
      primary_key :id
      foreign_key :board_id, :boards, null: false, on_delete: :cascade
      String :name, null: false
      Integer :position, null: false
      Integer :lock_version, null: false, default: 0
      unique [:board_id, :position], deferrable: :initially_deferred
    end

    create_table(:cards) do
      primary_key :id
      foreign_key :column_id, :kanban_columns, null: false, on_delete: :cascade, index: true
      String :title, null: false
      Integer :position, null: false
      Integer :lock_version, null: false, default: 0
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      unique [:column_id, :position], deferrable: :initially_deferred
    end

    create_table(:activities) do
      primary_key :id
      foreign_key :board_id, :boards, null: false, on_delete: :cascade, index: true
      foreign_key :card_id, :cards, on_delete: :set_null
      String :actor_name, null: false
      String :actor_color, null: false
      String :action, null: false
      String :message, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    # Every change to a board records one activity in the same transaction,
    # so each change is announced once, when it commits: to the board's own
    # channel, and to kanban_boards for the list of boards.
    run <<~SQL
      CREATE FUNCTION notify_kanban_activity() RETURNS trigger AS $$
      DECLARE
        payload text := json_build_object(
          'board_id', NEW.board_id,
          'activity_id', NEW.id
        )::text;
      BEGIN
        PERFORM pg_notify('kanban_board_' || NEW.board_id, payload);
        PERFORM pg_notify('kanban_boards', payload);
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER activities_notify
      AFTER INSERT ON activities
      FOR EACH ROW EXECUTE FUNCTION notify_kanban_activity();
    SQL
  end

  down do
    drop_table(:activities, :cards, :kanban_columns, :boards)
    run "DROP FUNCTION notify_kanban_activity()"
  end
end
