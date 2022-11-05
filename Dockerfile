# syntax = docker/dockerfile:experimental
ARG RUBY_VERSION=3.1.2
ARG VARIANT=jemalloc-slim
FROM quay.io/evl.ms/fullstaq-ruby:${RUBY_VERSION}-${VARIANT} as base

ARG BUNDLER_VERSION=2.3.11

ARG BUNDLE_WITHOUT=development:test
ARG BUNDLE_PATH=vendor/bundle
ENV BUNDLE_PATH ${BUNDLE_PATH}
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}

SHELL ["/bin/bash", "-c"]

RUN mkdir /app
WORKDIR /app
RUN mkdir -p tmp/pids

######################
## build js runtime ##
######################

FROM node:19.0.0-alpine3.15 as build-js

COPY lib/mayu/client /build

WORKDIR /build

RUN \
    npm install && \
    npm run build:production && \
    rm -r node_modules

################
## build base ##
################

FROM base as build-base

WORKDIR /build

ENV DEV_PACKAGES git build-essential wget vim curl gzip xz-utils npm webp imagemagick brotli

RUN \
    --mount=type=cache,id=dev-apt-cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,id=dev-apt-lib,sharing=locked,target=/var/lib/apt \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y ${DEV_PACKAGES} && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN gem install -N bundler -v ${BUNDLER_VERSION}

####################
## build mayu gem ##
####################

FROM build-base as build-gem

COPY mayu-live.gemspec Gemfile* ./
COPY lib/mayu/version.rb lib/mayu/version.rb
RUN bundle && rm -rf vendor/bundle/ruby/*/cache

COPY COPYING README.md .
COPY exe ./exe
COPY sorbet ./sorbet
COPY lib ./lib

COPY --from=build-js /build/dist lib/mayu/client/dist
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

FROM base

COPY --from=build-app /app /app

ENV PORT 3000

WORKDIR /app

CMD ["bin/mayu", "serve", "--disable-sorbet"]
