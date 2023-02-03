# typed: true
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "vendor", "patches"))

require "async/barrier"
require "async/clock"
require "async/container"
require "async/container/controller"
require "async/http/body"
require "async/http/body/hijack"
require "async/http/client"
require "async/http/endpoint"
require "async/http/internet"
require "async/http/server"
require "async/http/statistics"
require "async/io"
require "async/io/buffer"
require "async/io/endpoint"
require "async/io/host_endpoint"
require "async/io/shared_endpoint"
require "async/io/socket"
require "async/io/ssl_endpoint"
require "async/io/ssl_socket"
require "async/io/stream"
require "async/io/trap"
require "async/io/unix_endpoint"
require "async/notification"
require "async/pool/controller"
require "async/queue"
require "async/reactor"
require "async/semaphore"
require "async/task"
require "async/variable"
require "async/wrapper"
require "base64"
require "bigdecimal"
require "bigdecimal/util"
require "brotli"
require "bundler/setup"
require "console/logger"
require "console/terminal"
require "date"
require "digest"
require "digest/sha2"
require "haml"
require "haml/parser"
require "image_size"
require "io/console"
require "listen"
require "mayucss"
require "mime/types"
require "nanoid"
require "nokogiri"
require "openssl"
require "pathname"
require "pp"
require "prettier_print"
require "prometheus/client"
require "prometheus/client/data_stores/direct_file_store"
require "prometheus/client/registry"
require "prometheus/middleware/collector"
require "prometheus/middleware/exporter"
require "protocol/http"
require "protocol/http/body/file"
require "psych"
require "rack/utils"
require "rake"
require "rake/clean"
require "rake/dsl_definition"
require "rake/tasklib"
require "rouge"
require "rouge/formatter"
require "rouge/lexers/haml"
require "rouge/lexers/ruby"
require "rouge/themes/molokai"
require "source_map"
require "svg_optimizer"
require "syntax_tree"
require "syntax_tree/dsl"
require "syntax_tree/haml"
require "syntax_tree/xml"
require "terminal-table"
require "toml-rb"
require "uri"
