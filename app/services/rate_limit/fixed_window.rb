# frozen_string_literal: true

module RateLimit
  # Counts requests for one subject in fixed windows, using Rails.cache.
  class FixedWindow
    Result = Struct.new(:limited, :limit, :remaining, :retry_after, keyword_init: true) do
      def limited?
        limited
      end
    end

    def initialize(subject:, limit:, window_seconds: 60)
      @subject = subject
      @limit = limit.to_i
      @window_seconds = window_seconds
    end

    def self.enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("RATE_LIMIT_ENABLED", "true"))
    end

    def consume!
      return Result.new(limited: false, limit: @limit, remaining: @limit, retry_after: 0) if @limit <= 0 || !self.class.enabled?

      now = Time.current.to_i
      key = "rate_limit:#{@subject}:#{now / @window_seconds}"
      count = Rails.cache.increment(key, 1, expires_in: @window_seconds + 1)
      # Some stores return nil on first write; treat as 1.
      count = 1 if count.nil?

      limited = count > @limit
      Result.new(
        limited: limited,
        limit: @limit,
        remaining: [ @limit - count, 0 ].max,
        retry_after: limited ? (@window_seconds - (now % @window_seconds)) : 0
      )
    end
  end
end
