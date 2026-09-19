require "json"
require "openssl"
require "async/http/client"
require "async/http/endpoint"
require "protocol/http/body/wrapper"

class OpenRouterChat
  DEFAULT_URL = "https://openrouter.ai/api/v1/chat/completions"
  DEFAULT_MODEL = "openrouter/free"
  DEFAULT_SITE_URL = "https://mayu.live/"
  DEFAULT_SITE_TITLE = "Mayu Live"

  NETWORK_ERRORS = [
    Errno::ETIMEDOUT,
    Errno::ECONNRESET,
    Errno::EPIPE,
    SocketError,
    IOError,
    EOFError,
    OpenSSL::SSL::SSLError
  ].freeze

  class UnauthorizedError < StandardError
  end

  class NetworkError < StandardError
  end

  class StreamingResponseParser < ::Protocol::HTTP::Body::Wrapper
    SKIP = Object.new

    # Inspired by https://github.com/socketry/async-ollama/blob/main/lib/async/ollama/wrapper.rb
    def initialize(...)
      super

      @buffer = "".b
      @offset = 0

      @response = ""
    end

    def read
      return if @buffer.nil?

      loop do
        if (event = next_event)
          line, index, delimiter_size = event
          @buffer = @buffer.byteslice(index + delimiter_size, @buffer.bytesize - index - delimiter_size)
          @offset = 0

          parsed = parse_event(line)
          return parsed unless parsed.equal?(SKIP)
        end

        if (chunk = super)
          @buffer << chunk
        else
          return nil if @buffer.empty?

          line = @buffer
          @buffer = nil
          @offset = 0

          parsed = parse_event(line)
          return parsed unless parsed.equal?(SKIP)

          return nil
        end
      end
    end

    def each
      super do |line|
        case line
        in error: {message:}
          raise UnauthorizedError, message
        in choices: [{delta: {content:}}, *]
          @response << content
          yield content if block_given?
        end
      end

      @response
    end

    def join
      each {}
      @response
    end

    def next_event
      lf_index = @buffer.index("\n\n", @offset)
      crlf_index = @buffer.index("\r\n\r\n", @offset)

      case [lf_index, crlf_index].compact.min
      in nil
        nil
      in ^lf_index
        [@buffer.byteslice(@offset, lf_index - @offset), lf_index, 2]
      in ^crlf_index
        [@buffer.byteslice(@offset, crlf_index - @offset), crlf_index, 4]
      end
    end

    def parse_event(event)
      data =
        event.each_line(chomp: true).filter_map do |line|
          line = line.delete_suffix("\r")
          next if line.empty? || line.start_with?(":")
          next unless line.start_with?("data:")

          line.delete_prefix("data:").delete_prefix(" ")
        end

      return SKIP if data.empty?

      json = data.join("\n")
      return nil if json == "[DONE]"

      ::JSON.parse(json, symbolize_names: true)
    end
  end

  Message = Data.define(:role, :content)

  def initialize(
    url: DEFAULT_URL,
    model: DEFAULT_MODEL,
    temperature: 0.8,
    max_tokens: 2048,
    top_p: 0.1,
    system_message: nil,
    site_url: DEFAULT_SITE_URL,
    site_title: DEFAULT_SITE_TITLE
  )
    @url = url

    @model = model
    @temperature = temperature
    @max_tokens = max_tokens
    @top_p = top_p
    @site_url = site_url
    @site_title = site_title

    @messages = []

    @messages.push(Message[:system, system_message]) if system_message

    @endpoint = Async::HTTP::Endpoint.parse(url)
  end

  def marshal_dump
    [@url, @model, @messages, @temperature, @max_tokens, @top_p, @site_url, @site_title]
  end

  def marshal_load(state)
    @url, @model, @messages, @temperature, @max_tokens, @top_p, @site_url, @site_title = state
    @endpoint = Async::HTTP::Endpoint.parse(@url)
  end

  def complete(message, &)
    @messages.push(Message["user", message])

    response =
      Async::HTTP::Client.open(@endpoint, retries: 0) do |client|
        res =
          client.post(
            @endpoint.url.path,
            headers,
            JSON.generate(
              {
                messages: @messages.map(&:to_h),
                model: @model,
                temperature: @temperature,
                max_tokens: @max_tokens,
                top_p: @top_p,
                stream: true
              }
            )
          )

        StreamingResponseParser.wrap(res).each(&)
      end

    @messages.push(Message["assistant", response])

    response
  rescue *NETWORK_ERRORS => error
    @messages.pop
    raise NetworkError,
      "OpenRouter request failed. Please try again.",
      cause: error
  rescue ::Protocol::HTTP::Error => error
    @messages.pop
    raise NetworkError,
      "OpenRouter request failed. Please try again.",
      cause: error
  rescue
    @messages.pop
    raise
  end

  private

  def headers
    {
      "content-type": "application/json",
      authorization: "Bearer #{openrouter_api_key}",
      "http-referer": @site_url,
      "x-openrouter-title": @site_title
    }
  end

  def openrouter_api_key
    ENV.fetch("OPENROUTER_API_KEY") do
      raise UnauthorizedError, "OPENROUTER_API_KEY is not set"
    end
  end
end

Default = OpenRouterChat
