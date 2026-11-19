# frozen_string_literal: true

module RateLimit
  # Applied before the operator key is checked, so it also slows key guessing.
  class PerOperatorIp < FixedWindow
    def initialize(ip:, limit: nil, window_seconds: 60)
      super(
        subject: "operator_ip:#{ip}",
        limit: limit || ENV.fetch("OPERATOR_RATE_LIMIT_PER_MINUTE", "30"),
        window_seconds: window_seconds
      )
    end
  end
end
