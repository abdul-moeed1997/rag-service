# frozen_string_literal: true

module RateLimit
  class PerApiKey < FixedWindow
    def initialize(api_key:, limit: nil, window_seconds: 60)
      super(
        subject: "api_key:#{api_key.id}",
        limit: limit || ENV.fetch("RATE_LIMIT_PER_MINUTE", "60"),
        window_seconds: window_seconds
      )
    end
  end
end
