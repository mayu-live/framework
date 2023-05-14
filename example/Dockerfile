FROM ruby:3.2.2-alpine3.17 as base

ARG BUNDLER_VERSION=2.4.6
ARG BUNDLE_WITHOUT=development:test
ARG BUNDLE_PATH=vendor/bundle
ENV BUNDLE_PATH ${BUNDLE_PATH}
ENV BUNDLE_WITHOUT ${BUNDLE_WITHOUT}
RUN gem install -N bundler -v ${BUNDLER_VERSION}
RUN apk update && apk add --no-cache curl bash jemalloc gcompat
SHELL ["/bin/bash", "-c"]
WORKDIR /app

FROM base AS install
RUN apk update && apk add --no-cache build-base gzip libwebp-tools imagemagick brotli
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
