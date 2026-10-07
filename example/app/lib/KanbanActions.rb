Kanban = import("/models/Kanban")

# Everything that changes a kanban board. Each change is one transaction that
# first locks the board's row, so changes to the same board run one at a time
# and positions stay contiguous, and that records one activity. The activity
# trigger then notifies everyone watching the board, once, on commit.
#
# `actor` is the visitor making the change: a hash with :name and :color.
module KanbanActions
  # Raised when a change is based on an outdated card or column, because
  # someone else changed or deleted it first.
  class Conflict < StandardError
  end

  DEFAULT_COLUMNS = ["To do", "Doing", "Done"].freeze

  # Longer names and titles are cut off. Inputs should set maxlength to match.
  MAX_LENGTH = 100
  MAX_DESCRIPTION_LENGTH = 500

  # Limits that keep the public demo's tables small. Creating a board deletes
  # the oldest boards beyond MAX_BOARDS, and each board keeps only its newest
  # activities. A board or column that is full refuses new columns or cards.
  MAX_BOARDS = Integer(ENV.fetch("KANBAN_MAX_BOARDS", "10"))
  MAX_COLUMNS = Integer(ENV.fetch("KANBAN_MAX_COLUMNS", "6"))
  MAX_CARDS = Integer(ENV.fetch("KANBAN_MAX_CARDS", "20"))
  KEEP_ACTIVITIES = Integer(ENV.fetch("KANBAN_KEEP_ACTIVITIES", "50"))

  extend self

  # Boards with how many columns and cards they have, in one query.
  def board_summaries
    boards = Sequel[:boards]
    columns = Sequel[:kanban_columns]
    cards = Sequel[:cards]

    Kanban::Board
      .left_join(:kanban_columns, board_id: boards[:id])
      .left_join(:cards, column_id: columns[:id])
      .group(boards[:id], boards[:name])
      .order(boards[:id])
      .select(
        boards[:id],
        boards[:name],
        Sequel.function(:count, columns[:id]).distinct.as(:column_count),
        Sequel.function(:count, cards[:id]).as(:card_count)
      )
      .naked
      .all
  end

  # The board with its columns and their cards, in three queries.
  def load_board(board_id)
    Kanban::Board.where(id: board_id).eager(columns: :cards).first
  end

  def recent_activities(board_id, limit: 10)
    Kanban::Activity.where(board_id:).reverse(:id).limit(limit).all
  end

  def create_board(name, actor)
    name = limit(name)

    db.transaction do
      board = Kanban::Board.create(name:)
      DEFAULT_COLUMNS.each_with_index do |column_name, position|
        Kanban::Column.create(board_id: board.id, name: column_name, position:)
      end
      record(board.id, actor, "created_board", "created the board")

      oldest = Kanban::Board.exclude(id: Kanban::Board.reverse(:id).limit(MAX_BOARDS).select(:id))
      oldest.select_map(:id).each { delete_board(it) }

      board
    end
  end

  # The foreign keys delete the board's columns, cards and activities with it,
  # so there is no activity left to announce this, and it notifies directly.
  # Notifications sent in a transaction are delivered when it commits.
  def delete_board(board_id)
    db.transaction do
      Kanban::Board.where(id: board_id).delete
      payload = JSON.generate({board_id:, deleted: true})
      db.notify("kanban_board_#{board_id}", payload:)
      db.notify("kanban_boards", payload:)
    end
  end

  def add_card(column_id, title, actor, description: "")
    title = limit(title)
    description = limit(description, MAX_DESCRIPTION_LENGTH)
    board_id = find_column(column_id).board_id

    db.transaction do
      lock_board(board_id)
      # Someone may have deleted the column before the board was locked.
      column = find_column(column_id)
      position = Kanban::Card.where(column_id:).count
      raise Conflict, full_column_message(column) if position >= MAX_CARDS

      card = Kanban::Card.create(column_id:, title:, description:, position:)
      record(column.board_id, actor, "created", "added “#{title}” to #{column.name}", card:)
    end
  end

  # Changes the title and description of a card, if it is still the version
  # the edit started from.
  def update_card(card_id, lock_version, actor, title:, description:)
    title = limit(title)
    description = limit(description, MAX_DESCRIPTION_LENGTH)
    board_id = board_id_for_card(card_id)

    db.transaction do
      lock_board(board_id)
      card = current_card(card_id, lock_version)
      old_title = card.title
      next if title == old_title && description == card.description

      card.update(title:, description:)

      if title == old_title
        record(board_id, actor, "edited", "edited “#{title}”", card:)
      else
        record(board_id, actor, "renamed", "renamed “#{old_title}” to “#{title}”", card:)
      end
    end
  end

  def delete_card(card_id, actor)
    board_id = board_id_for_card(card_id)

    db.transaction do
      lock_board(board_id)
      card = Kanban::Card.with_pk(card_id) or next
      close_gap(Kanban::Card.where(column_id: card.column_id), card.position)
      card.destroy
      record(board_id, actor, "deleted", "deleted “#{card.title}”")
    end
  end

  # Moves a card to `to_index` among the other cards in `to_column_id`.
  def move_card(card_id, to_column_id, to_index, lock_version, actor)
    board_id = board_id_for_card(card_id)

    db.transaction do
      lock_board(board_id)
      card = current_card(card_id, lock_version)
      to_column = Kanban::Column.where(id: to_column_id, board_id:).first
      raise Conflict, "That column was deleted." unless to_column

      others = Kanban::Card.where(column_id: to_column.id).exclude(id: card.id)
      if to_column.id != card.column_id && others.count >= MAX_CARDS
        raise Conflict, full_column_message(to_column)
      end

      to_index = to_index.clamp(0, others.count)
      next if card.column_id == to_column.id && card.position == to_index

      from_column_id = card.column_id
      close_gap(Kanban::Card.where(column_id: from_column_id), card.position)
      open_gap(others, to_index)
      card.update(column_id: to_column.id, position: to_index)

      message =
        if from_column_id == to_column.id
          "reordered “#{card.title}” in #{to_column.name}"
        else
          "moved “#{card.title}” to #{to_column.name}"
        end
      record(board_id, actor, "moved", message, card:)
    end
  end

  def add_column(board_id, name, actor)
    name = limit(name)

    db.transaction do
      lock_board(board_id)
      position = Kanban::Column.where(board_id:).count
      if position >= MAX_COLUMNS
        raise Conflict, "This board already has #{MAX_COLUMNS} columns, the most it can have."
      end

      Kanban::Column.create(board_id:, name:, position:)
      record(board_id, actor, "column_created", "added the column #{name}")
    end
  end

  def rename_column(column_id, name, lock_version, actor)
    name = limit(name)
    board_id = find_column(column_id).board_id

    db.transaction do
      lock_board(board_id)
      column = current_column(column_id, lock_version)
      old_name = column.name
      column.update(name:)
      record(board_id, actor, "column_renamed", "renamed the column #{old_name} to #{name}")
    end
  end

  def delete_column(column_id, actor)
    board_id = find_column(column_id).board_id

    db.transaction do
      lock_board(board_id)
      column = Kanban::Column.with_pk(column_id) or next
      if Kanban::Card.where(column_id:).any?
        raise Conflict, "Move or delete the cards in #{column.name} first."
      end

      close_gap(Kanban::Column.where(board_id:), column.position)
      column.destroy
      record(board_id, actor, "column_deleted", "deleted the column #{column.name}")
    end
  end

  # Moves a column to `to_index` among the board's other columns.
  def move_column(column_id, to_index, lock_version, actor)
    board_id = find_column(column_id).board_id

    db.transaction do
      lock_board(board_id)
      column = current_column(column_id, lock_version)
      others = Kanban::Column.where(board_id:).exclude(id: column.id)
      to_index = to_index.clamp(0, others.count)
      next if column.position == to_index

      close_gap(Kanban::Column.where(board_id:), column.position)
      open_gap(others, to_index)
      column.update(position: to_index)
      record(board_id, actor, "column_moved", "moved the column #{column.name}")
    end
  end

  private

  def db = Kanban::Board.db

  def limit(text, length = MAX_LENGTH) = text[0, length]

  def lock_board(board_id)
    Kanban::Board.for_update.with_pk(board_id) or
      raise Conflict, "This board was deleted."
  end

  def board_id_for_card(card_id)
    Kanban::Card
      .join(:kanban_columns, id: :column_id)
      .where(Sequel[:cards][:id] => card_id)
      .get(Sequel[:kanban_columns][:board_id]) or
      raise Conflict, "Someone deleted this card."
  end

  def find_column(column_id)
    Kanban::Column.with_pk(column_id) or
      raise Conflict, "Someone deleted this column."
  end

  # The card as it is now, if it is still the version the change was based on.
  def current_card(card_id, lock_version)
    card = Kanban::Card.with_pk(card_id)
    raise Conflict, "Someone deleted this card." unless card
    return card if card.lock_version == lock_version

    raise Conflict, conflict_message(card)
  end

  def current_column(column_id, lock_version)
    column = find_column(column_id)
    return column if column.lock_version == lock_version

    raise Conflict, "Someone changed the column #{column.name} first."
  end

  def full_column_message(column)
    "#{column.name} already has #{MAX_CARDS} cards, the most a column can have."
  end

  def conflict_message(card)
    activity = Kanban::Activity.where(card_id: card.id).reverse(:id).first
    who = activity&.actor_name || "Someone"
    "#{who} changed “#{card.title}” first."
  end

  # Positions are contiguous from 0. Removing the item at `position` moves
  # everything after it up one; inserting at `position` moves them down one.
  def close_gap(dataset, position)
    dataset.where(Sequel[:position] > position).update(position: Sequel[:position] - 1)
  end

  def open_gap(dataset, position)
    dataset.where(Sequel[:position] >= position).update(position: Sequel[:position] + 1)
  end

  # Callers hold the board lock, so trimming the older activities cannot race
  # with another change to the same board.
  def record(board_id, actor, action, message, card: nil)
    activity = Kanban::Activity.create(
      board_id:,
      card_id: card&.id,
      actor_name: actor.fetch(:name),
      actor_color: actor.fetch(:color),
      action:,
      message:
    )

    activities = Kanban::Activity.where(board_id:)
    activities.exclude(id: activities.reverse(:id).limit(KEEP_ACTIVITIES).select(:id)).delete

    activity
  end
end

Default = KanbanActions
