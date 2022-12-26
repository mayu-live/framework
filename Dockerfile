# syntax = docker/dockerfile:experimental

######################
## build js runtime ##
######################

FROM node:19.3.0-alpine3.17 as build-js

WORKDIR /build

COPY package.json package-lock.json /build
COPY lib/mayu/client/package.json /build/lib/mayu/client/

RUN npm install

COPY lib/mayu/client /build/lib/mayu/client

RUN \
    npm run build:production -w lib/mayu/client && \
    rm -r node_modules

################
## build-base ##
################

FROM registry.fly.io/mayu-ruby:3.2-slim-bullseye as build-base

ARG BUNDLER_VERSION=2.4.1
ARG BUNDLE_WITHOUT=development:test
ARG BUNDLE_PATH=vendor/bundle
ENV BUNDLE_PATH ${BUNDLE_PATH}
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}

SHELL ["/bin/bash", "-c"]

WORKDIR /build

ENV DEV_PACKAGES git build-essential wget vim curl gzip xz-utils npm webp imagemagick brotli

RUN \
    --mount=type=cache,id=dev-apt-cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,id=dev-apt-lib,sharing=locked,target=/var/lib/apt \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y ${DEV_PACKAGES} && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN gem install -N bundler -v ${BUNDLER_VERSION}

###############
## build-gem ##
###############

FROM build-base as build-gem

COPY mayu-live.gemspec Gemfile* ./
COPY lib/mayu/version.rb lib/mayu/version.rb
RUN bundle && rm -rf vendor/bundle/ruby/*/cache

COPY COPYING README.md .
COPY exe ./exe
COPY sorbet ./sorbet
COPY lib ./lib

COPY --from=build-js /build/lib/mayu/client/dist lib/mayu/client/dist
RUN brotli lib/mayu/client/dist/*.{js,map}

RUN gem build

#######################
## build example app ##
#######################

FROM build-base as build-app

WORKDIR /app

COPY example/Gemfile* ./
COPY --from=build-gem /build/mayu-live-*.gem vendor/cache/
RUN \
    sed -i 's/, path: "\.\."//' Gemfile && \
    ls -l vendor/cache && \
    bundle install && \
    bundle binstubs mayu-live && \
    rm -rf vendor/bundle/ruby/*/cache && \
    rm -rf vendor/cache

COPY example/mayu.toml .
COPY example/app ./app

ENV MAYU_SECRET_KEY "nothing secret here, we just need to set something"
RUN bin/mayu build

#######################
## build final image ##
#######################

# FROM registry.fly.io/mayu-ruby:3.2-alpine3.17
FROM registry.fly.io/mayu-ruby:3.2-slim-bullseye


ARG BUNDLER_VERSION=2.4.1
ARG BUNDLE_WITHOUT=development:test
ARG BUNDLE_PATH=vendor/bundle
ENV BUNDLE_PATH ${BUNDLE_PATH}
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}

SHELL ["/bin/bash", "-c"]

RUN mkdir /app
WORKDIR /app
RUN mkdir -p tmp/pids

ENV PROD_PACKAGES curl

RUN \
    --mount=type=cache,id=dev-apt-cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,id=dev-apt-lib,sharing=locked,target=/var/lib/apt \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y ${PROD_PACKAGES} && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN gem install -N bundler -v ${BUNDLER_VERSION}
# COPY --from=build-app /app/Gemfile /app/Gemfile.lock /app/
# COPY --from=build-app /app/vendor /app/vendor
# RUN bundle install && \
#     rm -rf vendor/bundle/ruby/*/cache && \
#     rm -rf vendor/cache

COPY fly /fly
COPY --from=build-app /app /app

ENV PORT 3000

CMD ["bin/mayu", "serve", "--disable-sorbet"]
