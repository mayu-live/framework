# Mayu Live ![Ruby build status](https://github.com/mayu-live/framework/actions/workflows/ruby.yml/badge.svg) ![Node.js build status](https://github.com/mayu-live/framework/actions/workflows/node.js.yml/badge.svg)

Mayu is a real-time server-side component-based
VDOM rendering framework written in Ruby.

It is very early in development and nothing is guaranteed to work.
Still trying to figure out how to make a framework that is both
easy to use and fun to work with.

Some parts are quite messy and some files are very long.
This is fine. I like to paint with a broad brush until
things are put in place and things feel right.

# Getting started

## Install dependencies

Install Ruby dependencies

    bundle

Install node dependencies

    npm install

## Start the example app

    bin/mprocs

Then open https://localhost:9292/ in your browser.

Mayu uses [falcon](https://github.com/socketry/falcon) which generates a
self-signed certificate for localhost.

Depending on your system/browser you might need to do one of the following:

<details>
  <summary><strong>MacOS:</strong> Add the certificate to the keychain</summary>
  <ol>
    <li>Open `~/.localhost/localhost.crt` with Keychain Access.</li>
    <li>Choose `Get Info` and open `Trust` then choose `Always trust`.</li>
    <li>Restart your browsers.</li>
  </ol>
</details>

<details>
  <summary><strong>Chrome:</strong> Enable self-signed certs for localhost</summary>
  Go to `chrome://flags/#allow-insecure-localhost` and enable the setting.
  This will allow requests to localhost over HTTPS even when an invalid
  certificate is presented.
</details>

<details>
  <summary><strong>Firefox:</strong> Add an exception for the certificate</summary>
  Firefox will show **Warning: Potential Security Risk Ahead**.
  Click `Advanced`, then `Accept the Risk and Continue` to add an exception
  for this certificate.
</details>

> ℹ️ Note about Firefox: I've never been able to inspect Server-Sent Events
> in the Developer Tools. So if you're trying to debug them, try a
> Chromium-based browser.

## Run the tests

    rake test

# Features

Most of these features are implemented.

There is no guarantee that they work yet.

## 100% server side

This means that all rendering is done on the server,
and even callback handlers run on the server.
There is no need to implement an API, you access databases
and private APIs from your callback handlers.

Mayu detects changes in the VDOM-tree and sends instructions
on how to patch the DOM to the browser via
[Server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events).

Callbacks are just regular `POST` requests.

## 100% async

[socketry/async](https://github.com/socketry/async) makes it possible
to do all this without blocking.

```ruby
# components/Clock.rb
mount do
  loop do
    update(time: Time.now.to_s)
    sleep 0.5
  end
end

# stree-ignore
render do
  h.div do
    h.p state[:time]
  end.div
end
```

This will print the current server time.

The component will render only once every second even though it updates twice per second, since the time string only changes once per second.

## Components

Components are the building blocks of a Mayu application.
They contain logic and return other components or HTML elements.

You might be familiar with ReactJS and other component based
rendering libraries. This is the same thing, but in Ruby.

## CSS modules

[CSS Modules](https://github.com/css-modules/css-modules) makes sure
that all CSS class names are scoped locally.
You can access styles in a component using the `styles` method.

```css
/* components/Example.css */
.box {
  padding: 1px;
  border: 1px solid #000;
}

.hello {
  font-weight: bold;
}

.button {
  background: #0f0;
  color: #fff;
}
```

```ruby
# components/Example.rb
render do
  h.div class: styles.outer do
    h.p "Hello world", class: styles.hello
    h.button "Click me", class: styles.button
  end.div
end
```

This would generate the following HTML:

```html
<div class="box-MjQSEK">
  <p class="hello-vmTY0O">Hello world</p>
  <button class="button-qQao_H">Click me!</button>
</div>
```

This will be inserted in the HEAD:

```html
<link rel="stylesheet" href="/__mayu/assets/f934819a6d2a3f41509c86da3e27d88b36d119db52e03003477486dbee8df3fc.css">
```

Only the CSS for the components currently on the page will
be included with the HTML. With HTTP/2 all the CSS files load
in parallel which makes everything super fast.

## State management

Mayu comes with some basic state management inspired by
[Redux Toolkit](https://redux-toolkit.js.org/).

This is implemented but not yet integrated into the VDOM logic.

[Example store](https://github.com/mayu-live/prototype/blob/main/example/store/auth.rb)

Ideally I would want something like [XState](https://xstate.js.org/),
but I'm not experienced with it so I can't make anything like it.

## Simple routing

Routing is inspired by the
[Next.js Layouts RFC](https://nextjs.org/blog/layouts-rfc).

Here's the structure of a blog app:

```
app
├── page.rb
├── page.css
├── layout.rb
├── layout.css
├── about
│   ├── page.rb
│   └── page.css
└── posts
    ├── page.rb
    ├── page.css
    ├── layout.rb
    ├── layout.css
    └── [id]
        └── page.rb
        ├── page.css
```

This would create the following routes:

| **path**      | **component**            | **layouts**                           |
| ------------- | ------------------------ | ------------------------------------- |
| `/`           | `app/page.rb`            | `app/layout.rb`                       |
| `/about/`     | `app/about/page.rb`      | `app/layout.rb`                       |
| `/posts/`     | `app/posts/page.rb`      | `app/layout.rb` `app/posts/layout.rb` |
| `/posts/:id/` | `app/posts/[id]/page.rb` | `app/layout.rb` `app/posts/layout.rb` |
| `/*`          | `app/404.rb`             | `app/layout.rb`                       |

Look in `example/app` for examples.

## Hot reloading

Components and styles update immediately in the browser as you edit files.
No browser refresh needed.

## Small browser footprint

Everything is minified and optimized and deliviered over HTTP/2.

![Request waterfall screenshot](https://quad.pe/e/h9BqRqnMwh.png)

## Templating

There is a basic templating engine inspired by Markaby.
A difference is that you have to write `h.div` instead of just `div`
and that you have to close tags with `end.div`.

It looks like this:

```ruby
# stree-ignore
render do
  h.div do
    h.h1 "Page title"
    h.ul do
      3.times do |i|
        h.li "Item #{i + 1}"
      end
    end.ul
  end.div
end
```

I don't know why I made it so that tags have to be closed.
I had some idea about static typing and I don't like having
waterfalls with `end` I guess.

There is some funky stuff going on with scoping due to `instance_eval`
and while it works reasonably well, it's not very comfortable to use.

Ideally I would want to use [Rux](https://github.com/camertron/rux),
however I encountered some parsing issues and I don't know how to
fix them. Sometimes it would interpret indentation as space (` `)
and I don't know how to patch the ruby plugin for treesitter to
support this syntax. It would be pretty awesome though.

A nice thing with JSX is that it separates markup and logic.
You can look at a React component and you can distinguish elements
from logic very easily because the syntax is different from regular
JavaScript.

# Implementation notes

## Tests

Tests are located in the `lib/`-directory next to their implementation.
So for `lib/mayu/state.rb` the test would be located in
`lib/mayu/state.test.rb`.

I have always liked this convention in the JS-world.
It's nice to have things that belong together in the same place,
rather to have a separate tree for tests.

There aren't many tests yet. Kinda painting with a broad brush at the moment.

## Virtual DOM

Components return a `VDOM::Descriptor` which has a `type`, `props` and a `key`,
similar to React, and `props` can also contain children.
`VDOM::VTree` is responsible for keeping track of the `VDOM::VNode`s that make
up the application. A `VNode` has a `Descriptor` and children which is an array
of `VNode` objects. It can also have a component, in that case it would call
the appropriate lifecycle methods of that component and pass its descriptors'
props to the component before rendering.

The child diffing algorithm is a little bit inefficient. I have tried several
times to implement the algorithm in snabbdom/preact/million, but they rely
on DOM-operations for ordering (`node.insertBefore`) and the algorithm has
to take care of that and make sure that the order is exactly the same in the
VDOM as in the DOM after all patch operations have been applied.

The child diffing algorithm makes a few unnecessary moves, and there's lots of
room for improvement, but at least the order is correct.

## Server

The server logic is located in `lib/mayu/server2`.
Look at the `build` method to find all the endpoints.

All requests are routed to the `InitSession` rack app, and then they get
a session id and a session token back as a HTTPOnly cookie, and then they
will use this cookie to connect to the SSE-endpoint to receive updates.

It also serves some static files.

I would like to rewrite the server in Go and have it basically just deal
with connections, and then it would communicate to Ruby processes over
[NATS](https://nats.io/).

## Static typing

Most files are strictly typed with [Sorbet](https://sorbet.org/).
Some aren't strictly typed yet, but the goal is to have `# typed: strict`
everywhere, even in components.

# Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mayu-live/framework.
This project is intended to be a safe, welcoming space for collaboration,
and contributors are expected to adhere to the
[code of conduct](https://github.com/mayu-live/framework/blob/main/CODE_OF_CONDUCT.md).
