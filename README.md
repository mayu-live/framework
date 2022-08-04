# Mayu Live

## Description

Here comes a description of what this is, and what it aims to be.
The project is very early on in development so it's likely that most
things still haven't been implemented yet.

- Ruby based Virtual DOM diffing inspired by React JS.
- JSX-inspired syntax.
- Server side rendering.
- DOM-updates are streamed from the server.
- No API required, callbacks just work.
- No JavaScript required.
- CSS-modules — no scoping issues.
- Async updates - no blocking.
- XState-compatible state machines and immutable data structures.
- Module system inspired by JavaScript.
- Hot module replacement in development mode.
- Image scaling, compression.
- Source maps for rux files.
- Designed to be hosted on services like fly.io
  where you can deploy apps to different regions
  for lower latency.
- Mayu means river in Quechua.

## App structure

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

## Some ideas

### Module system

Maybe base imports/exports on [digital-fabric/modulation](https://github.com/digital-fabric/modulation).

Or maybe not. Maybe better if all .rux files only export one component.

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

## Implementation status

### VDOM

The VDOM is working, however some parts of the code are quite messy.
Should probably be rewritten once or twice while finding out what
is working and not.

#### Missing features

* Contexts are highly prioritized.
  It should be possible to provide any sort of data to child
  components at any level, and those child components that subscribe
  to those context changes should be updated...
  It would probably be possible to register callbacks for each
  context in the VTree object, and add some sort of special hooks
  to some special Provider/Consumer objects so that the providers
  can update the consumers...
* Child diffing algorithm is not very efficient.
  It seems to work well for simple demos, but it
  generates too many move instructions.
  I tried to make an implementation based on the
  algorithm in snabbdom/vue but the resulting order
  in the VDOM and the DOM would be different every
  time and I just got tired of it and wrote an
  unoptimized implementation, that while inefficient,
  at least gets the order right.
* Rendering should be paused while the user is disconnected
  to prevent sending a bunch of irrelevant updates whenever
  they come online.

### Components

What is working is asynchronous stuff... Even handlers are async.
However, it seems like each handler can only run once at a time.

#### Missing features

* There needs to be a way to define inline stateless
  components. Not exactly sure how it would look.
* Prop type validation maybe?

### Modules

Do we need modules?
Maybe I'm too inspired by the JS world.

#### Missing features

* The entire thing needs to be rethought.
* The CSS for a component needs to be updated dynamically.
* Hot module replacement that works with images and everything.
* Some file watcher library would be good to use here to monitor
  all changes... Could maybe even instantiate some sort of tree
  similar to the VDOM tree and perform different actions when
  things change in the file tree...
  If a component uses an image, like this maybe:
  ```
  Logo = image("./Logo.png", format: :webp, versions: {
    500w: { max_width: 500 },
    800w: { max_width: 800 },
  })
  ```
  ... then the asset watcher thing could maybe see that if the image has
  changed, it should remove the old image files, and create new versions.
  Similar to mounting/unmounting in the VDOM...
  If we could make a more generic VDOM-library for dealing with any sort
  of changes, then we could do something like that.

### State management

Components currently basic state that they can pass to children via props.

Currrently working on getting something similar to Redux working...

#### `state/auth.rb`

```ruby
CurrentUserSelector = create_selector do |state|
  state.dig(:auth, :current_user)
end

LogIn = async_action(:log_in) do |store, username:, password:|
  user = DB[:users].where(username:)
  raise InvalidCredentials unless user
  user
end

initial_state(
  logging_in: false,
  current_user: nil,
  error: nil,
)

match(LogIn.pending) do |state|
  state[:error] = nil
  state[:logging_in] = true
end

match(LogIn.fulfilled) do |state, user|
  state[:logging_in] = false
  state[:current_user] = user
end

match(LogIn.rejected) do |state, error|
  case error
  when InvalidCredentials
    state[:error] = "Invalid credentials"
  else
    state[:error] = error.message
  end
  state[:logging_in] = false
end
```

#### `components/CurrentUser.mayu`

```ruby
use_store do |props|
  {
    current_user: CurrentUserSelector,
  }
end
```
```mayu
render do
  if current_user = store[:current_user]
    <p>{current_user[:name]}</p>
  end
    <p>Please log in!</p>
  end
end
```

#### Missing features

* I have been looking a lot at [XState](https://xstate.js.org/) which
  looks great, but I have never used it. I could probably implement
  something like Redux myself, but XState seems pretty complex.
  I do believe however that statecharts would be perfect for
  this project, so we should look into that.
  It would be great if the schema was compatible with XState too,
  to be able to use the visualizer.

### Assets

#### Missing features

* Not even images are handled or anything.
* For production builds, it should be possible to scan through
 the `app/`-directory, and for all assets that are found, :

### I18n

Translations should be stored in a format like the Rails translations...

Some translations can contain tags, so that you can do:

#### `i18n/en.yaml`

```
pages:
  page:
    title: "Title"
    welcome: "Welcome <bold>%{name}</bold> to my <red>webpage</red>"
  items:
    page:
      title: "Title"
      welcome: "Welcome <bold>%{name}</bold> to my <red>webpage</red>"
    [id]:
      page:
        title: "Showing item %{id}"
}
```

#### MyComponent

```
t("welcome",
  bold: <span style={{ fontWeight: "bold" }} />,
  red: <span style={{ color: "red" }} />,
)
```

Translations should always be scoped to the current page...
Components should have their own translations..

Idk, maybe even translations should be stored in the same directory as the components?
So that one doesn't have to jump around so much...

`MyComponent.mayu`, `MyComponent.css`, `MyComponent.en.i18n`, `MyComponent.es.i18n`

On the other hand it would yield a lot of files in each directory...

#### Missing features

* Nothing done.
* Need to implement some sort of parser that can insert components
  where the tags are... I have done this before in javascript.

### Pages and routing

Simple routing implemented but not integrated.
Based on next.js dynamic routing and new layout RFC.

So you create a page by putting it in `app/my-page/page.mayu` and it will get
the path `/my-page/`. A page is a component but if you do `import` it will
look for components in the `components/` directory, so you can't import other
pages. If you need to share functionality, put stuff in components.

