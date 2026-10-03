class Todo < Sequel::Model(:todos)
  # The shared todo list is public, so it keeps only its newest todos.
  KEEP = Integer(ENV.fetch("TODOS_KEEP", "30"))
  MAX_LENGTH = 100

  # Adds a todo and deletes the oldest ones beyond KEEP. The trigger
  # announces each insert and delete on the `todos` channel.
  def self.add(title)
    db.transaction do
      todo = create(title: title[0, MAX_LENGTH])
      dataset.exclude(id: dataset.reverse(:id).limit(KEEP).select(:id)).delete
      todo
    end
  end
end

Default = Todo
