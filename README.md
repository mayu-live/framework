# ![Mayu Live](https://raw.githubusercontent.com/mayu-live/framework/main/example/app/mayu-logo.svg)

[![Tests](https://img.shields.io/github/actions/workflow/status/mayu-live/framework/.github/workflows/test.yml?branch=main&label=Tests&style=flat-square)](https://github.com/mayu-live/framework/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/mayu-live/framework?sort=semver&style=flat-square)](https://github.com/mayu-live/framework/releases)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/w/mayu-live/framework/main?style=flat-square)](https://github.com/mayu-live/framework/commits)
[![License AGPL-3.0](https://img.shields.io/github/license/mayu-live/framework?style=flat-square)](https://github.com/mayu-live/framework/blob/main/COPYING) ![Status: Experimental](https://img.shields.io/badge/status-experimental-critical?style=flat-square)

[Documentation](https://mayu.live/docs)

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

A starter kit is available at
[github.com/mayu-live/starter](https://github.com/mayu-live/starter)!
If you have all dependencies installed, you will be able to deploy
an app to [Fly.io](https://fly.io/) within a few minutes without
having to configure anything!

### Core features:

- 100% Ruby
- 100% Server Side
- 100% Async
- Interactive web apps without JavaScript
- Hot-reloading in dev
- Automatic asset handling
- Built-in metrics
- File-system based routing inspired by [Next.js](https://nextjs.org/docs/routing/introduction)
- Designed for edge deployments
- Powerful and compact templating using [Haml](https://haml.info/)
- One component per file
- One file per component
- Lazy loading, prefetch hints, HTTP/2, caching

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
  - [Scoped CSS](#scoped-css)
  - [State management](#state-management)
  - [Path based routing](#path-based-routing)
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

Make sure that you have installed [Ruby](https://www.ruby-lang.org/en/downloads/)
and [NodeJS](https://nodejs.org/en/download/).
The required versions are specified in the file `.tool-versions`
in the project root.

[ImageMagick](https://github.com/ImageMagick/ImageMagick) and
[libwebp](https://chromium.googlesource.com/webm/libwebp) are
also required for resizing images.

Install Ruby dependencies:

    bundle install

Install node dependencies:

    npm install

Build browser runtime:

    npm run build

Start the example app

    cd example
    bundle install
    bin/mayu dev

Now, open https://localhost:9292/ in your browser.

HTTP/2 requires HTTPS to work, therefore in development mode,
Mayu will use the [localhost](https://github.com/socketry/localhost) gem
to generate a self-signed certificate for localhost.

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

Most of these features are implemented, however, there are lots of sneaky bugs.
Contributions in such as bug reports or pull requests are appreciated!
:green_heart:

The [example app](https://github.com/mayu-live/framework/blob/main/example/)
is deployed to [`https://mayu.live/`](https://mayu.live/) as a proof of concept.

## 100% server side

Mayu keeps all state on the server and all HTML is being rendered on the server.

There is no need to implement an API, you access databases
and private APIs directly in your callback handlers.

Mayu detects changes in components and sends instructions
on how to patch the DOM to the browser using the
[Streams API](https://developer.mozilla.org/en-US/docs/Web/API/Streams_API).
[Client stream implementation](https://github.com/mayu-live/framework/blob/main/lib/mayu/client/src/stream.ts).

Callbacks are regular `POST`-requests to
`/__mayu/session/#{session_id}/#{callback_id}`,
where the body contains the
[serialized event data](https://github.com/mayu-live/framework/blob/main/lib/mayu/client/src/serializeEvent.ts).

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

[Analog SVG clock component](https://github.com/mayu-live/framework/blob/main/example/app/components/Clock.haml)

### Async loading

It's also easy to defer rendering until some action has happened,
for example, the [form demo](https://mayu.live/demos/form) loads
tab content asynchronously when the mouse enters the tab header,
so when the user clicks the tab, the content is already loaded.

[Tabs implementation](https://github.com/mayu-live/framework/blob/main/example/app/components/Layout/Tabs.haml)

## Components

Components are the building blocks of a Mayu application.
They contain logic and return other components or HTML elements.

You might be familiar with ReactJS and other component based
rendering libraries. This is the same thing, but in Ruby.

## Scoped CSS

All class names and element names are given an unique name,
inspired by [CSS Modules](https://github.com/css-modules/css-modules).

Class names are applied automatically.

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

  button {
    background: #0f0;
    color: #fff;
  }
.box
  %p.hello Hello world
  %button Click me!
```

This would generate the following HTML:

```html
<div class="/app/components/Example.box?MjQSEK">
  <p class="/app/components/Example.hello?MjQSEK">Hello world</p>
  <button class="/app/components/Example_button?MjQSEK">Click me!</button>
</div>
```

Those are valid class names, as long as the characters are escaped in the
CSS-file. [Specification](https://www.w3.org/TR/css-syntax-3/#consume-name).

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

### Separate CSS-files

If you have very complex CSS, or maybe generate CSS-files,
you can create a `.css`-file right next to your component.

This does the same thing as the previous example:

#### `app/components/Example.css`

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

#### `app/components/Example.haml`

```haml
.box
  %p.hello Hello world
  %button.button Click me!
```

You can also mix the two styles.

### Source maps

You can debug the sources of your CSS using source maps.

![Source maps screenshot](https://user-images.githubusercontent.com/41148/199131855-d6159b68-649c-4c7a-baf1-e1ad2c9bd281.png)

## State management

Mayu comes with some basic state management inspired by
[Redux Toolkit](https://redux-toolkit.js.org/).

This is implemented but not yet integrated into the VDOM logic.

[Example store](https://github.com/mayu-live/prototype/blob/main/example/store/auth.rb)

Ideally I would want something like [XState](https://xstate.js.org/),
but I'm not experienced with it so I can't make anything like it.

## Path based routing

Routing is inspired by the
[Next.js Layouts RFC](https://nextjs.org/blog/layouts-rfc).

It's a simple and straight forward approach, and it's super
easy to locate files using a fuzzy finder plugin.

Here's the structure of a blog app:

```
app
├── root.haml
├── root.css
└── pages
    ├── page.haml
    ├── layout.haml
    ├── layout.css
    ├── about
    │   ├── page.haml
    │   └── page.css
    └── posts
        ├── page.haml
        ├── layout.haml
        └── :id
            └── page.haml
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

Before a server shuts down (when receiving the `SIGINT` signal),
it will pause all sessions, serialize and encrypt them, and send
them to the client and close the connection.

The client will then reconnect and post the encrypted session
which will be decrypted, verified, deserialized and resumed.

I don't know how stable this is at the moment.
Sometimes it seems like it can't restore components properly,
maybe when their implementation has changed.

Whenever [Issue #20](https://github.com/mayu-live/framework/issues/20)
has been fixed, it would be quite easy to serialize the browser DOM and
send it along with the encrypted state when resuming, and then use a
DOM-diffing algorithm (like [morphdom](https://github.com/patrick-steele-idem/morphdom))
on the browser DOM vs the DOM generated by the VDOM.

## Optimized data transfer

Everything is minified and optimized and deliviered over HTTP/2.
Images are scaled into different versions, non-binary assets are
compressed with Brotli.

Asset filenames are based on their content hash so that they can
be cached easily without having to worry about expiring them when
they change.

The message stream uses [DecompressionStream](https://wicg.github.io/compression/#decompression-stream)
with the [`deflate-raw`](https://wicg.github.io/compression/#supported-formats)
format. Browsers that don't support DecompressionStream will download a
replacement based on [fflate](https://github.com/101arrowz/fflate).

Messages are packed with [MessagePack](https://msgpack.org/index.html),
which is supposed to be very efficient, although it's also the largest
dependency at the moment. A good thing with MessagePack is that it
can send binary data, which is useful when transferring state.

First page load with Slow 3G throttling (no cache):

![Request waterfall](https://user-images.githubusercontent.com/41148/198865376-5382a538-44a3-4058-8ba6-6d178cc78b37.png)

Second page load with Slow 3G throttling (cache):

![Request waterfall](https://user-images.githubusercontent.com/41148/198865399-d4d428ec-89c6-4469-bec1-964040c41c2c.png)

## Realtime metrics

Mayu exposes a [Prometheus](https://prometheus.io/)-endpoint for metrics so you can see how your app performs.

Screenshots from [Grafana on Fly.io](https://fly.io/docs/reference/metrics/#managed-grafana-preview).

![Active sessions](https://user-images.githubusercontent.com/41148/193404404-9018c9d9-e575-48db-8845-3f56ced0c16f.png)
![Patch times and counts](https://user-images.githubusercontent.com/41148/193398411-cc5bf2d6-d353-42eb-bcf5-ccc1feb7099a.png)

## Haml

Mayu uses [Haml](https://haml.info/), it's pretty convenient.

Check out the [Haml Reference](https://haml.info/docs/yardoc/file.reference.html).
Mayu has some differences with regular Haml to make it work better with a virtual DOM,
[you can read more about that in the documentation](https://mayu.live/docs/components).

Look at this example:

[`./example/app/pages/Counter.haml`](https://github.com/mayu-live/framework/blob/main/example/app/pages/Counter.haml)

That above code will be transformed into something like this:

```ruby
# frozen_string_literal: true
Self =
  setup_component(
    assets: ["0tyaKLqdvUGGcwZkdPOdMiMoMZoO74sMmtyRTuksjaQ=.css"],
    styles: {
      __Card: "example/app/pages/Counter_Card?7d89edff",
      __article: "example/app/pages/Counter_article?7d89edff",
      __output: "example/app/pages/Counter_output?7d89edff",
      __button: "example/app/pages/Counter_button?7d89edff",
    },
  )
begin
  Card = import("/app/components/UI/Card")
  def self.get_initial_state(initial_value: 0, **) = { count: initial_value }
  def decrement_disabled = state[:count].zero?
  def handle_decrement
    update do |state|
      count = [0, state[:count] - 1].max
      { count: }
    end
  end
  def handle_increment
    update do |state|
      count = state[:count] + 1
      { count: }
    end
  end
end
public def render
  Mayu::VDOM::H[
    Card,
    Mayu::VDOM::H[
      :article,
      Mayu::VDOM::H[
        :button,
        "－",
        **mayu.merge_props(
          { class: :__button },
          { title: "Decrement" },
          {
            onclick: mayu.handler(:handle_decrement),
            disabled: decrement_disabled,
          },
        )
      ],
      Mayu::VDOM::H[
        :output,
        state[:count],
        **mayu.merge_props({ class: :__output })
      ],
      Mayu::VDOM::H[
        :button,
        "＋",
        **mayu.merge_props(
          { class: :__button },
          { title: "Increment" },
          { onclick: mayu.handler(:handle_increment) },
        )
      ],
      **mayu.merge_props({ class: :__article })
    ],
    **mayu.merge_props({ class: :__Card }, { class: :card })
  ]
end
```

[Check out more examples in the tests](https://github.com/mayu-live/framework/blob/main/lib/mayu/resources/transformers/haml.test.rb)

# Implementation notes

## Tests

Tests are located in the `lib/`-directory next to their implementation.
So for `lib/mayu/state.rb` the test would be located in
`lib/mayu/state.test.rb`.

This pattern is quite common in JavaScript
([Jest does this](https://jestjs.io/docs/configuration#testmatch-arraystring)),
and it's quite convenient to have things that are related close to each other,
rather than to have a separate tree for tests.

It's also preferred to test things on a higher level, and only write unit
tests for specific edge cases and trickier situations.
[Sorbet](https://sorbet.org/) is pretty good at finding errors.
If the higher level tests pass, then everything works as expected.

The example app could also be considered to be a test.
It should always work and be updated to use the latest features.

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
