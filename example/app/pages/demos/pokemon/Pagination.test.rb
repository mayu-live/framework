# frozen_string_literal: true

Pagination = import("./Pagination.haml")

def render_pagination(page:, total_pages:, total: total_pages * 24)
  render(
    Pagination,
    page:,
    total_pages:,
    total:,
    per_page: 24,
    per_page_options: [24, 48],
    link_params: {q: "char"},
    on_change_per_page: nil
  )
end

def test_pagination_items
  pagination = render_pagination(page: 1, total_pages: 1).get_component(Pagination).instance!

  items = ->(page, total_pages) {
    pagination.pagination_items(page:, total_pages:, window_size: 5)
  }

  assert_equal([1], items.call(1, 1))
  assert_equal([1, 2, 3, 4, 5, 6, 7], items.call(4, 7))
  assert_equal([1, 2, 3, 4, 5, 6, 7, 8], items.call(1, 8))
  assert_equal([1, 2, 3, 4, 5, 6, :gap, 50], items.call(1, 50))
  assert_equal([1, :gap, 23, 24, 25, 26, 27, :gap, 50], items.call(25, 50))
  assert_equal([1, :gap, 45, 46, 47, 48, 49, 50], items.call(50, 50))
end

def test_links_keep_the_query_and_disable_steps_at_the_ends
  screen = render_pagination(page: 1, total_pages: 3, total: 60)

  assert_equal("Showing 1–24 of 60", screen.get_by_css("p").text.split.join(" "))
  assert_equal("true", screen.get_by_text("← Previous")["aria-disabled"])
  assert_equal("?q=char&page=2&per_page=24", screen.get_by_text("Next →")["href"])

  screen = render_pagination(page: 3, total_pages: 3, total: 60)

  assert_equal("Showing 49–60 of 60", screen.get_by_css("p").text.split.join(" "))
  assert_equal("true", screen.get_by_text("Next →")["aria-disabled"])
end
