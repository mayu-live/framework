# frozen_string_literal: true

Todo = import("./Todo")

# Runs against DATABASE_URL inside a transaction that is always rolled back.
def test_adding_a_todo_deletes_the_oldest_beyond_the_limit
  skip "Set DATABASE_URL to run the todo tests" unless Database.enabled?

  Database.db.transaction(rollback: :always) do
    first = Todo.add("First")
    Todo::KEEP.times { Todo.add("Todo #{it}") }

    assert_equal(Todo::KEEP, Todo.count)
    assert_nil(Todo[first.id])
  end
end

def test_long_titles_are_cut_off
  skip "Set DATABASE_URL to run the todo tests" unless Database.enabled?

  Database.db.transaction(rollback: :always) do
    assert_equal(Todo::MAX_LENGTH, Todo.add("x" * 500).title.length)
  end
end
