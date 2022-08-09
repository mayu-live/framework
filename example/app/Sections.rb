SECTIONS = {
  "Interactive web apps without JavaScript" => [
    "You write all logic in Ruby. Everything runs on the server."
  ],
  "But how does it work?" => [
    "Mayu implements a Virtual DOM in Ruby. All DOM updates are streamed to the browser via Server-Sent Events.",
    "All callbacks run on the server. You can write to the database securely directly in an onsubmit-handler. There is no need to for an API. Your callback handlers are your endpoints.",
    "Mayu needs 10kB of JavaScript (before gzip) to be able to patch the DOM. This loads before the page has been rendered."
  ],
  "Efficient" => [
    "By utilizing async for Ruby to make things really fast. This also enables us to write async code without callbacks or promises.",
    "Designed to be deployed near users, either on fly.io or maybe even an on-premise Raspberry PI.",
    "HTTP/2 is supported out of the box. Actually only HTTP/2 is supported. This will make assets load in parallel (or will it? idk how this stuff works)",
    "Elements are interactive immediately as the page loads. No need to wait for a huge JS bundle to load for the page to become interactive."
  ],
  "Smooth developer experience" => [
    "Hot-reloading reloads your components as you edit them and shows the updates in real-time.",
    "Rubyists like Ruby because it's a very comfortable language to work with.",
    "Mayu extends Ruby with a JSX-inspired syntax to you get the feeling of writing HTML. NO IT DOES NOT!!! It was going to, but unfortunately there were some issues, mostly due to it not being supported anywhere. Now we get a clunkier syntax, but it should work with static typing and syntax highlighting everywhere.",
    "Asynchronous code without callbacks, again, thanks to the fantastic async library.",
    "All dependencies are explicit, so things will break early."
  ]
}

# stree-ignore
render do
  h.div do
    SECTIONS.each_with_index do |(title, paragraphs), i|
      h.section class: styles.section, key: i do
        h.div do
          h.h2 title, class: styles.title

          paragraphs.each_with_index do |paragraph, i|
            h.p paragraph, key: i
          end
        end.div
      end.section
    end
  end.div
end
