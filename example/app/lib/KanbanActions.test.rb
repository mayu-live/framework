# frozen_string_literal: true

KanbanActions = import("./KanbanActions")
Kanban = import("/models/Kanban")

ALICE = {name: "User111", color: "#e5484d"}.freeze
BOB = {name: "User222", color: "#0090ff"}.freeze

# These run against DATABASE_URL, inside a transaction that is always rolled
# back, so they leave no trace and send no notifications.
def with_board
  skip "Set DATABASE_URL to run the kanban tests" unless Database.enabled?

  Database.db.transaction(rollback: :always) do
    yield KanbanActions.create_board("Test board", ALICE)
  end
end

def positions(column)
  Kanban::Card.where(column_id: column.id).order(:position).select_map([:title, :position])
end

def columns_of(board)
  Kanban::Column.where(board_id: board.id).order(:position).all
end

def test_moving_a_card_keeps_positions_contiguous
  with_board do |board|
    todo, doing, _done = columns_of(board)
    %w[A B C].each { KanbanActions.add_card(todo.id, it, ALICE) }
    KanbanActions.add_card(doing.id, "D", ALICE)

    b = Kanban::Card.first(title: "B")
    KanbanActions.move_card(b.id, doing.id, 0, b.lock_version, BOB)

    assert_equal([["A", 0], ["C", 1]], positions(todo))
    assert_equal([["B", 0], ["D", 1]], positions(doing))

    c = Kanban::Card.first(title: "C")
    KanbanActions.move_card(c.id, todo.id, 0, c.lock_version, BOB)

    assert_equal([["C", 0], ["A", 1]], positions(todo))
  end
end

def test_moving_a_column
  with_board do |board|
    todo, = columns_of(board)
    KanbanActions.move_column(todo.id, 2, todo.lock_version, ALICE)

    assert_equal(["Doing", "Done", "To do"], columns_of(board).map(&:name))
    assert_equal([0, 1, 2], columns_of(board).map(&:position))
  end
end

def test_a_stale_version_is_a_conflict
  with_board do |board|
    todo, doing, = columns_of(board)
    KanbanActions.add_card(todo.id, "A", ALICE)
    card = Kanban::Card.first(title: "A")

    KanbanActions.rename_card(card.id, "A2", card.lock_version, ALICE)

    error = assert_raises(KanbanActions::Conflict) do
      KanbanActions.move_card(card.id, doing.id, 0, card.lock_version, BOB)
    end
    assert_equal("User111 changed “A2” first.", error.message)
  end
end

def test_every_change_records_one_activity
  with_board do |board|
    todo, doing, = columns_of(board)
    count = -> { Kanban::Activity.where(board_id: board.id).count }

    assert_equal(1, count.call)
    KanbanActions.add_card(todo.id, "A", ALICE)
    card = Kanban::Card.first(title: "A")
    KanbanActions.move_card(card.id, doing.id, 0, card.lock_version, BOB)
    assert_equal(3, count.call)

    activity = Kanban::Activity.where(board_id: board.id).reverse(:id).first
    assert_equal(["User222", "moved", card.id], [activity.actor_name, activity.action, activity.card_id])
  end
end

def test_board_summaries_count_columns_and_cards
  with_board do |board|
    todo, doing, = columns_of(board)
    KanbanActions.add_card(todo.id, "A", ALICE)
    KanbanActions.add_card(doing.id, "B", ALICE)

    summary = KanbanActions.board_summaries.find { it[:id] == board.id }
    assert_equal({column_count: 3, card_count: 2}, summary.slice(:column_count, :card_count))
  end
end
