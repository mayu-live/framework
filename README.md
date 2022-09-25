# Mayu Live ![Ruby build status](https://github.com/mayu-live/framework/actions/workflows/ruby.yml/badge.svg) ![Node.js build status](https://github.com/mayu-live/framework/actions/workflows/node.js.yml/badge.svg)

Mayu is a live streaming server side component-based
VirtualDOM rendering framework written in Ruby.

Everything runs on the server, except for a tiny little runtime that
deals with the connection to the server and updates the DOM.

It is very early in development and nothing is guaranteed to work.
Still trying to figure out how to make a framework that is both
easy to use and fun to work with.

Some parts are quite messy and some files are very long.
This is fine. I like to paint with a broad brush until
things are put in place and things feel right.

# Getting started

## Install dependencies

Install Ruby dependencies

    bundle install

Install node dependencies

    npm install

## Start the example app

    cd example2
    bundle install
    bin/mayu dev

Then open https://localhost:9292/ in your browser.

Mayu generates a self-signed certificate for localhost in development mode.

Depending on your system/browser you might need to do one of the following:

<details>
  <summary><strong>MacOS:</strong> Add the certificate to the keychain</summary>
  <blockquote>
      <ol>
        <li>Open <code>~/.localhost/localhost.crt</code> with Keychain Access.</li>
        <li>Choose <i>Get Info</i> and open <i>Trust</i> then choose `Always trust`.</li>
        <li>Restart your browsers.</li>
      </ol>
  </blockquote>
</details>

<details>
  <summary><strong>Chrome:</strong> Enable self-signed certs for localhost</summary>
  <blockquote>
      Go to <code>chrome://flags/#allow-insecure-localhost</code> and enable the setting.
      This will allow requests to localhost over HTTPS even when an invalid
      certificate is presented.
  </blockquote>
</details>

<details>
  <summary><strong>Firefox:</strong> Add an exception for the certificate</summary>
  <blockquote>
      Firefox will show <strong>Warning: Potential Security Risk Ahead</strong>.
      Click <i>Advanced</i>, then <i>Accept the Risk and Continue</i> to add an exception
      for this certificate.
  </blockquote>
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

Mayu detects changes in the VDOM and sends instructions
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

The component will render once every second even though it updates
twice per second, since the time string only changes once per second.

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

```
# components/Example.rux
render do
  <div class={styles.box}>
    <p class={styles.hello}>
      Hello world
    </p>
    <button class={styles.button}>
      Click me
    </button>
  </div>
end
```

This would generate the following HTML:

```html
<div class="box-MjQSEK">
  <p class="hello-vmTY0O">Hello world</p>
  <button class="button-qQao_H">Click me!</button>
</div>
```

This will be inserted into `<head>`:

```html
<link
  rel="stylesheet"
  href="/__mayu/static/NtXGjOdgHqDJUnAhmk3NwuzFnkk8Z1NlBCE_XykVE-8=.css"
/>
```

The browser will also be made aware of the assets used on a page via the
[Link](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Link)-header,
so that they can load even before the browser starts parsing the HTML.

    $ curl -i https://localhost:9292 -k
    HTTP/2 200
    content-length: 5260
    content-type: text/html; charset=utf-8
    link: </__mayu/static/jkA-D11H90ChVHYqIOKn8I_A4w2MJ4nG-UEVP19UGqg=.js>; rel=preload; as=script; crossorigin=anonymous; fetchpriority=high, </__mayu/static/NtXGjOdgHqDJUnAhmk3NwuzFnkk8Z1NlBCE_XykVE-8=.css>; rel=preload; as=style, </__mayu/static/u6rK2NKHRcFKribL1sMcDdr1gXHbgYIVznfN5RJEKCA=.css>; rel=preload; as=style, </__mayu/static/shJPApqH5hptQERL4DivMTX42leUQRht9vGW4X_Rr84=.css>; rel=preload; as=style, </__mayu/static/ZStAGN7uGe7CU3cxSgAIOL550d1VDqVDUzdiQuFOXo8=.css>; rel=preload; as=style

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
app/pages
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
    └── :id
        ├── page.rb
        └── page.css
```

This would create the following routes:

| **path**      | **component**                  | **layouts**                                       |
| ------------- | ------------------------------ | ------------------------------------------------- |
| `/`           | `app/pages/page.rb`            | `app/pages/layout.rb`                             |
| `/about/`     | `app/pages/about/page.rb`      | `app/pages/layout.rb`                             |
| `/posts/`     | `app/pages/posts/page.rb`      | `app/pages/layout.rb` `app/pages/posts/layout.rb` |
| `/posts/:id/` | `app/pages/posts/[id]/page.rb` | `app/pages/layout.rb` `app/pages/posts/layout.rb` |
| `/*`          | `app/pages/404.rb`             | `app/pages/layout.rb`                             |

Look in `example/app` for examples.

## Hot reloading

Components and styles update immediately in the browser as you edit files.
No browser refresh needed.

## Small browser footprint

Everything is minified and optimized and deliviered over HTTP/2.

![Request waterfall screenshot](https://quad.pe/e/h9BqRqnMwh.png)
![Request waterfall screenshot 22](https://quad.pe/e/OVWyi8tIRk.png)

## Templating

Mayu uses [Rux](https://github.com/camertron/rux) provides a JSX-like syntax,
so that you can write components like this:

```
def render
  <div>
    <p>Current time: {Time.now.to_s}</p>
  <div>
end
```

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

The child diffing algorithm is quite inefficient. I have tried to implement
the algorithm in snabbdom/preact/million several times, but they rely
on DOM-operations for ordering (`node.insertBefore`) and the algorithm has
to take care of that and make sure that the order is exactly the same in the
VDOM as in the DOM after all patch operations have been applied.

The child diffing algorithm makes a few unnecessary moves, and there's lots of
room for improvement, but at least the order is correct.

## Server

### Development server

There is a development server that enables hot reloading.

### Production server

The production server depends on the output from a build step that
parses all inputs and generates static files.

This way the server doesn't have to do
much to start in production mode...

## Static typing

Most files are strictly typed with [Sorbet](https://sorbet.org/).

Some aren't strictly typed yet, but the goal is to enable
strict typechecking everywhere.

# Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mayu-live/framework.
This project is intended to be a safe, welcoming space for collaboration,
and contributors are expected to adhere to the
[code of conduct](https://github.com/mayu-live/framework/blob/main/CODE_OF_CONDUCT.md).
