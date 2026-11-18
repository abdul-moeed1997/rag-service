# frozen_string_literal: true

module RateLimit
  class PerApiKey
    Result = Struct.new(:limited, :limit, :remaining, :retry_after, keyword_init: true) do
      def limited?
        limited
      end
    end

    def initialize(api_key:, limit: nil, window_seconds: 60)
      @api_key = api_key
      @limit = (limit || ENV.fetch("RATE_LIMIT_PER_MINUTE", "60")).to_i
      @window_seconds = window_seconds
    end

    def self.enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("RATE_LIMIT_ENABLED", "true"))
    end

    def consume!
      return Result.new(limited: false, limit: @limit, remaining: @limit, retry_after: 0) if @limit <= 0 || !self.class.enabled?

      window = Time.current.to_i / @window_seconds
      key = "rate_limit:api_key:#{@api_key.id}:#{window}"
      count = Rails.cache.increment(key, 1, expires_in: @window_seconds + 1)
      # Some stores return nil on first write; treat as 1.
      count = 1 if count.nil?

      remaining = [ @limit - count, 0 ].max
      limited = count > @limit
      retry_after = limited ? (@window_seconds - (Time.current.to_i % @window_seconds)) : 0

      Result.new(
        limited: limited,
        limit: @limit,
        remaining: remaining,
        retry_after: retry_after
      )
    end
  end
end
