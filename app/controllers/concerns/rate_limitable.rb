# frozen_string_literal: true

module RateLimitable
  extend ActiveSupport::Concern

  included do
    before_action :enforce_rate_limit!
  end

  private

  def enforce_rate_limit!
    return unless respond_to?(:current_api_key_for_rate_limit, true)
    return unless (api_key = current_api_key_for_rate_limit)

    result = RateLimit::PerApiKey.new(api_key: api_key).consume!
    response.set_header("X-RateLimit-Limit", result.limit.to_s)
    response.set_header("X-RateLimit-Remaining", result.remaining.to_s)

    return unless result.limited?

    response.set_header("Retry-After", result.retry_after.to_s)
    render json: {
      error: "rate_limited",
      message: "Rate limit exceeded. Try again in #{result.retry_after} seconds."
    }, status: :too_many_requests
  end

  def current_api_key_for_rate_limit
    @current_api_key
  end
end
