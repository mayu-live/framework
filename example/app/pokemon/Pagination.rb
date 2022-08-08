render do
  h.fieldset do
    h.legend "Page #{props[:page].succ} of #{props[:total_pages].succ}"
    h.button "Previous page",
      on_click: props[:on_click_prev]
    h.button "Next page",
      on_click: props[:on_click_next]
    h.div do
      h << "Per page: "
      h.select on_change: props[:on_change_per_page], value: props[:per_page] do
      [20, 40, 80].each do |value|
          h.option value.to_s, value:
        end
      end.select
    end.div
  end.fieldset
end
