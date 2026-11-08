# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:todos) do
      primary_key :id
      String :title, null: false
      TrueClass :done, null: false, default: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    # Every change to a todo is announced on the `todos` channel.
    run <<~SQL
      CREATE FUNCTION notify_todos() RETURNS trigger AS $$
      BEGIN
        PERFORM pg_notify(
          'todos',
          json_build_object('op', TG_OP, 'id', COALESCE(NEW.id, OLD.id))::text
        );
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER todos_notify
      AFTER INSERT OR UPDATE OR DELETE ON todos
      FOR EACH ROW EXECUTE FUNCTION notify_todos();
    SQL
  end

  down do
    drop_table(:todos)
    run "DROP FUNCTION notify_todos()"
  end
end
