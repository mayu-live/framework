# Models for the kanban demo. They are in one file because their associations
# refer to each other. Cards and columns use optimistic locking: every save
# bumps lock_version and fails if someone else saved first.
module Kanban
  class Board < Sequel::Model(:boards)
  end

  class Column < Sequel::Model(:kanban_columns)
    plugin :optimistic_locking
  end

  class Card < Sequel::Model(:cards)
    plugin :optimistic_locking
    plugin :timestamps
  end

  class Activity < Sequel::Model(:activities)
  end

  Board.one_to_many :columns, class: Column, key: :board_id, order: :position
  Board.one_to_many :activities, class: Activity, key: :board_id, order: Sequel.desc(:id)
  Column.many_to_one :board, class: Board
  Column.one_to_many :cards, class: Card, key: :column_id, order: :position
  Card.many_to_one :column, class: Column
  Activity.many_to_one :board, class: Board
  Activity.many_to_one :card, class: Card
end

Default = Kanban
