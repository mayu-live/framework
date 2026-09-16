# syntax=docker/dockerfile:1

# Builds the example app from the gems in this repository. The build context
# is the repository root, not this directory:
#
#   podman build -f example/Dockerfile -t mayu-example .
#   podman run --rm -p 3333:3333 -e MAYU_SECRET_KEY=secret mayu-example
#
# Only the browser runtime and the packaged gems come from the repository.
# Everything else is what a released mayu-live and mayu-build would give an
# app, so this doubles as a check that the packaged gems work.

# The browser runtime ships inside mayu-live.
FROM node:26-alpine AS client
WORKDIR /src
COPY package.json package-lock.json ./
COPY gems/mayu-live/lib/mayu/client/package.json gems/mayu-live/lib/mayu/client/
RUN npm ci
COPY gems/mayu-live/lib/mayu/client gems/mayu-live/lib/mayu/client
RUN npm run build

# Packages both gems the way a release does, then unpacks them where the
# example's Gemfile looks for its path gems. The app therefore installs
# exactly the files a published gem carries.
FROM ruby:4.0.6-alpine3.24 AS gems
WORKDIR /src
COPY gems gems
COPY --from=client /src/gems/mayu-live/lib/mayu/client/dist gems/mayu-live/lib/mayu/client/dist
RUN set -e; for name in mayu-live mayu-build; do \
      (cd "gems/${name}" && gem build "${name}.gemspec" --output "/tmp/${name}.gem"); \
      gem unpack "/tmp/${name}.gem" --target /gems; \
    done

# Installs every gem and builds the app's bundle and assets. This runs on
# Debian because klenod's CSS and JavaScript plugins ship prebuilt native
# gems for glibc, not for musl.
FROM ruby:4.0.6-slim AS build
WORKDIR /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential ca-certificates imagemagick libmagickwand-dev libsodium23 libssl-dev pkg-config \
  && rm -rf /var/lib/apt/lists/*
COPY --from=gems /gems /gems
COPY example/Gemfile example/Gemfile.lock ./
RUN bundle install
COPY example ./
RUN bin/mayu build

# Installs only what `mayu start` needs: mayu-build and klenod-build stay out.
FROM ruby:4.0.6-alpine3.24 AS runtime-gems
ENV BUNDLE_WITHOUT=development:test
WORKDIR /app
RUN apk add --no-cache build-base libsodium openssl-dev pkgconf
COPY --from=gems /gems /gems
COPY example/Gemfile example/Gemfile.lock ./
RUN bundle install

FROM ruby:4.0.6-alpine3.24 AS runtime
ENV BUNDLE_WITHOUT=development:test
ENV RUBY_YJIT_ENABLE=1
WORKDIR /app
RUN apk add --no-cache libsodium
COPY --from=runtime-gems /usr/local/bundle /usr/local/bundle
# Bundler needs every path gem in the Gemfile to exist, even in a group it
# does not install, so mayu-build's source comes along without its gems.
COPY --from=gems /gems /gems
COPY --from=build /app/Gemfile /app/Gemfile.lock /app/mayu.toml /app/app.mayu-bundle ./
COPY --from=build /app/bin ./bin
COPY --from=build /app/app ./app
COPY --from=build /app/.assets ./.assets
EXPOSE 3333
CMD ["bin/mayu", "start"]
