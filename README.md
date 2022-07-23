# Mayu Live

## Description

Here comes a description of what this is, and what it aims to be.
The project is very early on in development so it's likely that most
things still haven't been implemented yet.

* Ruby based Virtual DOM diffing inspired by React JS.
* JSX-inspired syntax.
* Server side rendering.
* DOM-updates are streamed from the server.
* No API required, callbacks just work.
* No JavaScript required.
* CSS-modules — no scoping issues.
* Async updates - no blocking.
* XState-compatible state machines and immutable data structures.
* Module system inspired by JavaScript.
* Hot module replacement in development mode.
* Image scaling, compression.
* Source maps for rux files.
* Designed to be hosted on services like fly.io
  where you can deploy apps to different regions
  for lower latency.
* Mayu means river in Quechua.

## Structure

A Mayu-app is structured like this:

```
my_app
├── App
│   ├── App.css
│   ├── App.rux
│   └── index.rux
├── mayu.yaml
├── bin
│   └── mayu
└── machines
```

In your `app/`-directory, you place all your application files.

## Requests

```
├── __mayu
│   ├── assets
│   │   ├── App-[hash].css
│   │   └── Logo-version-[hash].png
│   ├── events/:session_id
│   ├── handler/:session_id/:handler_id
│   └── live.js
└── * # catch-all route
```

All unmatched requests with the HTTP `Accept` header set to `text/html` will render the app.

## Implementation notes

### Module system

Maybe base imports/exports on [digital-fabric/modulation](https://github.com/digital-fabric/modulation).

### Images

Maybe could do something like:

```
Logo = image("./Logo.png", format: :webp, versions: {
  500w: { max_width: 500 },
  800w: { max_width: 800 },
})

render do
  <div>
    <img src={Logo} />
  </div>
end
```

In this case, `Logo` would be an instance of the struct `ImageDescriptor`:

```
class ImageDescriptor
  extend T::Struct

  class ImageSource
    extend T::Struct

    prop :url, String
    prop :width, Integer
    prop :height, Integer

    sig {returns(String)}
    def to_s() = url
  end
  
  prop :blur_data_url, String
  prop :content_type, String
  prop :sources, T::Array[ImageSource]

  sig {returns(String)}
  def to_s() = sources.first.to_s
end
```

All image versions will be created during build time.
It should also be possible to build once and sync images to a CDN
and then have all images being pointed to the CDN instead...
That would make the container images way smaller.

### Hosting

Provide a default configuration for hosting on fly.io and other services.
