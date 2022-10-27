# Mayu HAML guide

Mayu customizes HAML a little bit to make it more convenient.
Most things should work the same.

Fundamentally, it's all just syntactic sugar for
`Mayu::VDOM.h(type, *children, **props)`.

```haml
%MyButton(color="blue" shadowSize=2)
  Click Me
```

Compiles into:

```ruby
Mayu::VDOM.h(
  MyButton,
  "Click Me"
  color: "blue",
  shadowSize: 2,
)
```

This document was written very quickly. Contributions are appreciated.
It should also be added to the docs-section of the webpage, but waiting for
[#28](https://github.com/mayu-live/framework/issues/28) and
[#29](https://github.com/mayu-live/framework/issues/29).

## Simple component

Here's a simple component:

```haml
%p Hello world
```

## Multiple children

Only the last child is returned, so if you want to return
more than one element you need to group them.

```haml
%div
  %p Hello world
  %button Click me
```

## Interpolation

You can perform string interpolation in a lot of places:

```haml
:ruby
  text = "hello world"

%div
  %p Contents of text: #{text.inspect}
  %button(title=text) Button with a title
  %button{title: "text: #{text}"} Button with a title
```

## Callbacks

The first `:ruby`-filter block will be executed
in class scope of the component.

This is where you would set up state, lifecycle methods and callback handlers.

Attributes starting with `on` will automatically be bound to handlers.

```haml
:ruby
  def handle_click(event)
    Console.logger.info(self, event)
  end
%div
  %p Hello world
  %button(onclick=handle_click) Click me
```

This will be translated into:

```ruby
def handle_click(e)
  Console.logger.info(self, e)
end

def render
  Mayu::VDOM.h(:button, "Click me", **{ onclick: handler(:handle_click) })
end
```

This component works the same as this React component:

```jsx
export default function MyComponent() {
  function handleClick(e) {
    console.log('MyComponent', e)
  }

  return (
    <button on-click={handleClick}>
      Click me
    </button>
  )
}
```

## State

Set up state with `get_initial_state`,
read state with `state`,
and update state with `update`,

```haml
:ruby
  def self.get_initial_state(initial_count: 0, **props)
    { count: initial_count }
  end

  def handle_reset(_event)
    update(count: 0)
  end

  def handle_decrement(_event)
    update do |state|
      { count: state[:count] + 1 }
    end
  end

  def handle_decrement(_event)
    update do |state|
      { count: state[:count] - 1 }
    end
  end
%div
  %p Count: #{state[:count]}
  %button(onclick=handle_increment) Increment
  %button(onclick=handle_decrement) Decrement
  %button(onclick=handle_reset) Reset
```

## Early returns

I don't think this is possible in regular HAML,
but it makes sense to do it in Mayu.

```haml
:ruby
  def self.get_initial_state(**)
    { clicked: false }
  end

  def handle_click(_event)
    update(clicked: true)
  end
- if state[:clicked]
  - return
    %p You clicked the button.
%button(onclick=handle_click) Click me
```

## Lifecycle

There are a few lifecycle methods that can be useful.
It's all asynchronous so you can create loops and fetch data without blocking.

```haml
:ruby
  def self.get_initial_state(**)
    { count: 0 }
  end

  def mount
    loop do
      sleep 1

      update do |state|
        { count: state[:count] + 1 }
      end
    end
  end
%p Count: #{state[:count]}
```

## Whitespace

Here comes the biggest difference between Mayu HAML and regular HAML.
Whitespace is significant in HTML in some cases, and it's very important
for the patching algorithm that the DOM and the VDOM are in sync,
and every time there has been issues with it, it has been because
of unwanted whitespace.

Therefore, Mayu strips whitespaces in places where regular HAML doesn't,
and the operators for inserting whitespace work somewhat differently.

```haml
%p Hello world
%p
  Hello world
%p
  Hello
  world
%p

  Hello world
```

If you want to include whitespace between text and elements,
you need to use the `<` and `>` operators.

```haml
%p
  Read more on
  %a(href="https://github.com/mayu-live/framework")< GitHub
  \.
```

Notice the `<` after the link.
That operator will add a space before the element.
There will be no space between the link and the dot,
because the `>` operator was not used.

- `<` adds a space before an element.
- `>` adds a space after an element.

## Data fetching

This has nothing to do with HAML but I suppose this document will turn into
some proper documentation at some point, so I'm writing it here...

```haml
:ruby
  def self.get_initial_state(**)
    {
      result: nil,
      error: nil,
    }
  end

  def mount
    sleep 1

    res = helpers.fetch("https://pokeapi.co/api/v2/pokemon/#{props[:id]}")
    result = res.json(symbolize_names: true)
    update(result:)
  rescue => e
    update(error: e.message)
  end
:ruby
  state => { error:, result: }
- if error
  - return
    %p.error= error
- unless result
  - return
    %p Loading...
%p= result[:name]
```

## CSS-filter

Not supported yet!
The plan is to allow defining CSS inside components, like this:

```haml
:ruby
  def self.get_initial_state(**)
    { count: 0 }
  end

  def handle_click(e)
    update do |state|
      state[:count].succ
    end
  end
:css
  .outer {
    border: 1px solid #f0f;
  }

  .count {
    font-weight: bold;
  }

  .button {
    background: #0f0;
  }
.outer
  %p.count= state[:count]
  %button.button(onclick=handle_click) click me
```

Here's another idea, not sure if it's good or not, but maybe:

```haml
:css
  .outer {
    border: 1px solid #f0f;
  }

  button {
    background: #0f0;
  }
.outer
  %button click me
```

Matching by tag-names isn't allowed in Mayu because it wants to avoid surprises
that sometimes happen when things are matched unexpectedly.
In this example, it would be possible to generate a class name
for the button-tag, and then for each button element that matches in the same
component, it will just pull that class name from the component stylesheet.
Not sure about this, but I think it would be a good feature.

This means that tag name-selectors would be scoped to the current component,
and it looks kinda ridiculous to do: `%button.button` vs just `%button`...
