class Indexes
  def initialize
    @indexes = []
  end

  def append(id)
    @indexes.delete(id).append(id)
  end

  def insert_before(id, before)
    @indexes.delete(id)
    @indexes.insert(@indexes.index(before), id)
  end

  def remove(id)
    @indexes.remove(id)
  end

  def to_a
    @indexes
  end
end
