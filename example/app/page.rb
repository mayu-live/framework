FeatureList = import("FeatureList")
Sections = import("./Sections")

# stree-ignore
render do
  h.div do
    h.p "Mayu Live enables rich, real-time user experiences with server-rendered HTML."

    h[FeatureList]
    h[Sections]

    h.pre(class: styles.source) do
      h << source.to_s
    end.pre
  end.div
end
