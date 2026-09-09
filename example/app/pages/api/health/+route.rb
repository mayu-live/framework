# frozen_string_literal: true

def GET(_request)
  [200, {"content-type" => "application/json"}, '{"status":"ok"}']
end
