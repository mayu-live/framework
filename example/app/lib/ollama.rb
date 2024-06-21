require "async/http/client"

class Ollama
  DEFAULT_URL = "http://localhost:11434"
  DEFAULT_MODEL = "llama2"

  GenerateResponse =
    Data.define(
      :total_duration, # time spent generating the response
      :load_duration, # time spent in nanoseconds loading the model
      :sample_count, # number of samples generated
      :sample_duration, # time spent generating samples
      :prompt_eval_count, # number of tokens in the prompt
      :prompt_eval_duration, # time spent in nanoseconds evaluating the prompt
      :eval_count, # number of tokens the response
      :eval_duration, # time in nanoseconds spent generating the response
      :model,
      :created_at,
      :context # an encoding of the conversation used in this response, this can be sent in the next request to keep a conversational memory
    )

  def initialize(model: DEFAULT_MODEL, url: DEFAULT_URL)
    protocol =
      if url.start_with?("http:")
        Async::HTTP::Protocol::HTTP11
      else
        Async::HTTP::Protocol::HTTP2
      end

    @endpoint = Async::HTTP::Endpoint.parse(url, protocol:)
    @client = Async::HTTP::Client.new(@endpoint)
    @model = model
    @context = nil
  end

  def generate(prompt, system: nil, template: nil, options: {})
    res =
      @client.post(
        "/api/generate",
        nil,
        JSON.generate(
          {
            model: @model,
            prompt:,
            context: @context,
            template:,
            options:,
            system:
          }
        )
      )

    chunks = []

    res.each do |chunk|
      parsed = JSON.parse(chunk, symbolize_names: true)

      case parsed
      in error:
        raise error.to_s
      in { done: true, context: }
        @context = context
      in response:
        chunks << response
        yield response
      end
    end

    chunks.join.strip
  end
end
