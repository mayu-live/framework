# <img alt="Mayu Live" width="337" src="https://user-images.githubusercontent.com/41148/192179194-f44aed92-74a3-4b59-a25e-bf2a8d313796.png">

[![Ruby Workflow Status](https://img.shields.io/github/workflow/status/mayu-live/framework/Ruby/main?label=ruby&style=flat-square)](https://github.com/mayu-live/framework/actions/workflows/ruby.yml)
[![Node Workflow Status](https://img.shields.io/github/workflow/status/mayu-live/framework/Node.js%20CI/main?label=js&style=flat-square)](https://github.com/mayu-live/framework/actions/workflows/node.js.yml)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/w/mayu-live/framework/main?style=flat-square)](https://github.com/mayu-live/framework/commits)
[![License AGPL-3.0](https://img.shields.io/github/license/mayu-live/framework?style=flat-square)](https://github.com/mayu-live/framework/blob/main/COPYING)

# Description

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

### Core features:

- 100% Ruby
- 100% server side
- 100% asynchronous
- No JavaScript necessary
- Reactive components (server side Virtual DOM)
- Hot-reloading in dev
- Automatic asset handling
- Built-in metrics

## Table of contents

- [Description](#description)
- [Getting started](#getting-started)
  - [Install dependencies](#install-dependencies)
  - [Start the example app](#start-the-example-app)
  - [Run the tests](#run-the-tests)
- [Features](#features)
  - [100% server side](#100-server-side)
  - [100% async](#100-async)
  - [Components](#components)
  - [CSS modules](#css-modules)
  - [State management](#state-management)
  - [Simple routing](#simple-routing)
  - [Hot reloading](#hot-reloading)
  - [Optimized data transfer](#optimized-data-transfer)
  - [Realtime metrics](#realtime-metrics)
  - [Haml](#haml)
- [Implementation notes](#implementation-notes)
  - [Tests](#tests)
  - [Virtual DOM](#virtual-dom)
  - [Server](#server)
    - [Development server](#development-server)
    - [Production server](#production-server)
  - [Static typing](#static-typing)
- [Contributing](#contributing)

# Getting started

## Install dependencies

Install Ruby dependencies

    bundle install

Install node dependencies

    npm install

Build browser runtime

    npm run build

## Start the example app

    cd example
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

### `app/components/Clock.haml`

```haml
:ruby
  mount do
    loop do
      update(time: Time.now.to_s)
      sleep 0.5
    end
  end
%p= state[:time]
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

### `app/components/Example.css`

```css
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

### `app/components/Example.haml`

```haml
.box
  %p.hello Hello world
  %button.button Click me!
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

### Inline CSS

You can also write CSS inside the `.haml` file, like this:

### `app/components/Example.haml`

```haml
:css
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
.box
  %p.hello Hello world
  %button.button Click me!
```

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
├── page.haml
├── page.css
├── layout.haml
├── layout.css
├── about
│   ├── page.haml
│   └── page.css
└── posts
    ├── page.haml
    ├── page.css
    ├── layout.haml
    ├── layout.css
    └── :id
        ├── page.haml
        └── page.css
```

This would create the following routes:

| **path**      | **component**                    | **layouts**                                           |
| ------------- | -------------------------------- | ----------------------------------------------------- |
| `/`           | `app/pages/page.haml`            | `app/pages/layout.haml`                               |
| `/about/`     | `app/pages/about/page.haml`      | `app/pages/layout.haml`                               |
| `/posts/`     | `app/pages/posts/page.haml`      | `app/pages/layout.haml` `app/pages/posts/layout.haml` |
| `/posts/:id/` | `app/pages/posts/[id]/page.haml` | `app/pages/layout.haml` `app/pages/posts/layout.haml` |
| `/*`          | `app/pages/404.haml`             | `app/pages/layout.haml`                               |

For a real-world example, check out
[`example/app/pages/`](https://github.com/mayu-live/framework/tree/main/example/app/pages).

## Hot reloading

There is a resource system inspired by JavaScript bundlers that loads all
types of files.

### Development mode

Components and styles update immediately in the browser as you edit files.
No browser refresh needed.

## Production mode

As soon as a server receives `SIGINT`, it will pause all sessions,
serialize and encrypt the entire session, send it to the client and
close the connection. The client will then reconnect and post the
encrypted session which will be decrypted, verified, deserialized
and resumed.

I don't know how well this works in practice.
Whenever [Issue #20](https://github.com/mayu-live/framework/issues/20)
has been fixed, I believe that it would be quite easy to just serialize
the DOM in the browser and send it along with the encrypted state when
resuming, and then it would just diff the browser DOM against the DOM
generated by the VDOM...

## Optimized data transfer

Everything is minified and optimized and deliviered over HTTP/2.
Images are scaled into different versions, non-binary assets are
compressed with Brotli.

The message stream uses [DecompressionStream](https://wicg.github.io/compression/#decompression-stream)
with the [`deflate-raw`](https://wicg.github.io/compression/#supported-formats)
format. Browsers that don't support DecompressionStream will download a
replacement based on [fflate](https://github.com/101arrowz/fflate).

Messages are packed with [MessagePack](https://msgpack.org/index.html),
which is supposed to be very efficient, although it's also the largest
dependency at the moment. A good thing with MessagePack is that it
can send binary data, which is useful when transferring state.

![Request waterfall screenshot](https://quad.pe/e/h9BqRqnMwh.png)
![Request waterfall screenshot 22](https://quad.pe/e/OVWyi8tIRk.png)

## Realtime metrics

Mayu exposes a [Prometheus](https://prometheus.io/)-endpoint for metrics so you can see how your app performs.
Screenshots from [Grafana on Fly.io](https://fly.io/docs/reference/metrics/#managed-grafana-preview).

![Active sessions](https://user-images.githubusercontent.com/41148/193404404-9018c9d9-e575-48db-8845-3f56ced0c16f.png)
![Patch times and counts](https://user-images.githubusercontent.com/41148/193398411-cc5bf2d6-d353-42eb-bcf5-ccc1feb7099a.png)

## Haml

Mayu uses [Haml](https://haml.info/), it's pretty convenient.

Check out the [Haml Reference](https://haml.info/docs/yardoc/file.reference.html).
Mayu has some differences with regular Haml to make it work better with a virtual DOM,
some of these differences are documented in [./haml-guide.md](./haml-guide.md).

Look at this example:

[`./example/app/pages/Counter.haml`](https://github.com/mayu-live/framework/blob/main/example/app/pages/Counter.haml)

That above code will be transformed into something like this:

```ruby
def self.get_initial_state(initial_value: 0, **)
  { count: initial_value }
end

def handle_decrement(_)
  update { |state| { count: [0, state[:count].pred].max } }
end

def handle_increment(_)
  update { |state| { count: state[:count].succ } }
end

def render
  Mayu::VDOM.h(
    :div,
    Mayu::VDOM.h(
      :button,
      ("-"),
      **{
        title: "Decrement",
        on_click: handler(:handle_decrement),
        disabled: state[:count].zero?
      },
      class: styles[:button]
    ),
    Mayu::VDOM.h(:span, (state[:count]), class: styles[:count]),
    Mayu::VDOM.h(
      :button,
      ("+"),
      **{ title: "Increment", on_click: handler(:handle_increment) },
      class: styles[:button]
    ),
    class: styles[:counter]
  )
end
```

[Check out more examples in the tests](https://github.com/mayu-live/framework/blob/main/lib/mayu/resources/transformers/haml.test.rb)

# Implementation notes

## Tests

Tests are located in the `lib/`-directory next to their implementation.
So for `lib/mayu/state.rb` the test would be located in
`lib/mayu/state.test.rb`.

I have always liked this convention in the JS-world.
It's nice to have things that belong together in the same place,
rather to have a separate tree for tests.

There aren't many tests. Some things should really be tested,
but tests also add some overhead. I think it's better to test
things implicitly on a higher level rather than locking down
the implementation too much...

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

The server is configured in [`mayu.toml`](https://github.com/mayu-live/framework/blob/main/example/mayu.toml)
in the project root.

### Development

For development you probably want these settings:

```toml
[dev.server]
count = 1
hot_swap = true
self_signed_cert = true
```

### Production

The production server depends on the output from a build step that
parses all inputs and generates static files.

```toml
[dev.server]
hot_swap = false
self_signed_cert = false
```

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
