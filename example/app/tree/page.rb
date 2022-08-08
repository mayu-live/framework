DirectoryListing = import("./DirectoryListing")

render do
  h.div do
    h.h1 "App tree"
    h.p "This page shows the file structure of the example project (this webpage)."

    h.ul do
      h[DirectoryListing,
        path: File.expand_path(File.join(File.dirname(__FILE__), '..', '..')),
        initial_open: true]
    end.ul
  end.div
end
