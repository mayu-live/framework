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

#######################################################

FROM base as build

ENV DEV_PACKAGES git build-essential wget vim curl gzip xz-utils nodejs npm

RUN \
    --mount=type=cache,id=dev-apt-cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,id=dev-apt-lib,sharing=locked,target=/var/lib/apt \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y ${DEV_PACKAGES} && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN gem install -N bundler -v ${BUNDLER_VERSION}

COPY mayu-live.gemspec Gemfile* ./
COPY lib/mayu/version.rb /app/lib/mayu/version.rb
RUN bundle && rm -rf vendor/bundle/ruby/*/cache

COPY . .

# RUN rake build
RUN \
    cd lib/mayu/client && \
    npm install && \
    npm run build:production && \
    rm -r node_modules
RUN gem build
RUN \
    mkdir -p example2/vendor/cache && \
    cp mayu-live-*.gem example2/vendor/cache

RUN \
    mkdir -p example2/vendor/mayu && \
    cp lib/mayu/client/dist/live.js example2/vendor/mayu/live.js

RUN \
    cd example2 && \
    bundle && \
    rm -rf vendor/bundle/ruby/*/cache && \
    bin/mayu build

#######################################################

FROM base

# ENV PACKAGES postgresql-client file vim curl gzip
#
# RUN --mount=type=cache,id=prod-apt-cache,sharing=locked,target=/var/cache/apt \
#     --mount=type=cache,id=prod-apt-lib,sharing=locked,target=/var/lib/apt \
#     apt-get update -qq && \
#     apt-get install --no-install-recommends -y \
#     ${PACKAGES} && \
#     rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=build /app /app

ENV PORT 3000

WORKDIR /app/example2

CMD ["bin/mayu", "serve"]
