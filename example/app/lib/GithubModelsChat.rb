class GithubModelsChat
  DEFAULT_URL = "https://models.inference.ai.azure.com/chat/completions"
  DEFAULT_MODEL = "Ministral-3B"

  class UnauthorizedError < StandardError
  end

  class StreamingResponseParser < ::Protocol::HTTP::Body::Wrapper
    # Inspired by https://github.com/socketry/async-ollama/blob/main/lib/async/ollama/wrapper.rb
    def initialize(...)
      super

      @buffer = String.new.b
      @offset = 0

      @response = String.new
    end

    def read
      return if @buffer.nil?

      while true
        if index = @buffer.index("\n\n", @offset)
          line = @buffer.byteslice(@offset, index - @offset)
          @buffer = @buffer.byteslice(index + 2, @buffer.bytesize - index - 1)
          @offset = 0

          return parse_line(line)
        end

        if chunk = super
          @buffer << chunk
        else
          return nil if @buffer.empty?

          line = @buffer
          @buffer = nil
          @offset = 0

          return parse_line(line)
        end
      end
    end

    def each
      super do |line|
        case line
        in error: { code: "unauthorized", message: }
          raise UnauthorizedError, message
        in choices: [{ delta: { content: } }, *]
          @response << content
          yield content if block_given?
        end
      end

      @response
    end

    def join
      self.each {}
      @response
    end

    def parse_line(line)
      case line.delete_prefix("data: ")
      in "[DONE]"
        nil
      in json
        ::JSON.parse(json, symbolize_names: true)
      end
    end
  end

  Message = Data.define(:role, :content)

  def initialize(
    url: DEFAULT_URL,
    model: DEFAULT_MODEL,
    temperature: 0.8,
    max_tokens: 2048,
    top_p: 0.1,
    system_message: nil
  )
    @url = url

    @model = model
    @temperature = temperature
    @max_tokens = max_tokens
    @top_p = top_p

    @messages = []

    @messages.push(Message[:system, system_message]) if system_message

    @endpoint = Async::HTTP::Endpoint.parse(url)
    @client = Async::HTTP::Client.new(@endpoint)
  end

  def marshal_dump
    [@url, @model, @messages, @temperature, @max_tokens, @top_p]
  end

  def marshal_load(state)
    @url, @model, @messages, @temperature, @max_tokens, @top_p = @state
    @endpoint = Async::HTTP::Endpoint.parse(@url)
    @client = Async::HTTP::Client.new(@endpoint)
  end

  def complete(message, &)
    @messages.push(Message["user", message])

    res =
      @client.post(
        @endpoint.url.path,
        {
          "content-type": "application/json",
          authorization: "Bearer #{github_token}"
        },
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

    response = StreamingResponseParser.wrap(res).each(&)

    @messages.push(Message["assistant", response])

    response
  end

  private

  def github_token
    ENV.fetch("GITHUB_TOKEN") do
      raise UnauthorizedError, "GITHUB_TOKEN is not set"
    end
  end
end
