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

FROM ruby:3.2.0-slim-bullseye as build-base

ARG BUNDLER_VERSION=2.4.1
ARG BUNDLE_WITHOUT=development:test
ARG BUNDLE_PATH=vendor/bundle
ENV BUNDLE_PATH ${BUNDLE_PATH}
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}

SHELL ["/bin/bash", "-c"]

WORKDIR /build

ENV DEV_PACKAGES git build-essential wget vim curl gzip xz-utils webp imagemagick brotli

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
RUN bin/mayu build && rm -rf vendor

##############
## app-base ##
##############

FROM ruby:3.2.0-alpine3.17 as app-base

ARG BUNDLER_VERSION=2.4.1
ARG BUNDLE_WITHOUT=development:test
ARG BUNDLE_PATH=vendor/bundle
ENV BUNDLE_PATH ${BUNDLE_PATH}
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
RUN gem install -N bundler -v ${BUNDLER_VERSION}

RUN apk update && apk add --no-cache curl bash jemalloc
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

RUN MALLOC_CONF=stats_print:true ruby -e "exit"
# ENV MALLOC_CONF=narenas:2

SHELL ["/bin/bash", "-c"]

##############
## pack-app ##
##############

FROM app-base as pack-app

WORKDIR /app
RUN apk add --no-cache --virtual run-dependencies build-base git
COPY --from=build-app /app /app
COPY --from=build-gem /build/mayu-live-*.gem vendor/cache/
RUN bundle install && rm -rf vendor/cache

#######################
## build final image ##
#######################

FROM app-base

RUN mkdir /app
WORKDIR /app
RUN mkdir -p tmp/pids

COPY fly /fly
COPY --from=pack-app /app /app

ENV PORT 3000

ENTRYPOINT ["/fly/entrypoint.sh"]
CMD ["bin/mayu", "serve", "--disable-sorbet"]
