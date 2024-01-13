FROM ruby:3.3.0-alpine3.18 as base

ARG BUNDLER_VERSION=2.5.3
ARG BUNDLE_WITHOUT=development:test
ARG BUNDLE_PATH=vendor/bundle
ENV BUNDLE_PATH ${BUNDLE_PATH}
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
RUN gem install -N bundler -v ${BUNDLER_VERSION}
RUN apk update && apk add --no-cache \
  curl bash jemalloc gcompat libsodium
SHELL ["/bin/bash", "-c"]
WORKDIR /app

FROM base AS install
RUN apk update && apk add --no-cache \
  build-base gzip brotli \
  pkgconfig imagemagick-dev
COPY Gemfile* .
RUN bundle install
COPY . .
RUN bin/mayu build

FROM base AS final
COPY .fly /fly
COPY --from=install /app /app
ENV PORT 3000
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENTRYPOINT ["/fly/entrypoint.sh"]
CMD ["bin/mayu", "serve", "--disable-sorbet"]
