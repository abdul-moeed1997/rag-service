# frozen_string_literal: true

# Decides who is calling before any action runs, and applies the rate limit.
#
# Every controller is `:tenant` by default (tenant API key required).
# Declare another caller kind with `admit`:
#
#   admit :operator   # OPERATOR_API_KEY, rate limited per IP
#   admit :public     # no credentials, no rate limit
module RequestGate
  extend ActiveSupport::Concern

  CALLER_KINDS = %i[tenant operator public].freeze

  included do
    class_attribute :caller_kind, instance_writer: false, default: :tenant
    before_action :admit_request!
  end

  class_methods do
    def admit(kind)
      raise ArgumentError, "Unknown caller kind: #{kind.inspect}" unless CALLER_KINDS.include?(kind)

      self.caller_kind = kind
    end
  end

  private

  attr_reader :current_api_key

  def current_tenant
    current_api_key.tenant
  end

  def admit_request!
    case caller_kind
    when :public then nil
    when :operator then admit_operator!
    else admit_tenant!
    end
  end

  def admit_tenant!
    @current_api_key = ApiKey.authenticate(bearer_token || request.headers["X-Api-Key"].presence)
    return deny("Invalid or missing API key") unless @current_api_key

    throttle!(RateLimit::PerApiKey.new(api_key: @current_api_key))
  end

  def admit_operator!
    return if throttle!(RateLimit::PerOperatorIp.new(ip: request.remote_ip))

    expected = ENV["OPERATOR_API_KEY"].to_s
    provided = (bearer_token || request.headers["X-Operator-Key"]).to_s
    return if expected.present? && provided.present? && secure_match?(expected, provided)

    deny("Invalid or missing operator API key")
  end

  # Returns true when the request was rejected.
  def throttle!(limiter)
    result = limiter.consume!
    response.set_header("X-RateLimit-Limit", result.limit.to_s)
    response.set_header("X-RateLimit-Remaining", result.remaining.to_s)
    return false unless result.limited?

    response.set_header("Retry-After", result.retry_after.to_s)
    render json: {
      error: "rate_limited",
      message: "Rate limit exceeded. Try again in #{result.retry_after} seconds."
    }, status: :too_many_requests
    true
  end

  def deny(message)
    render json: { error: "unauthorized", message: message }, status: :unauthorized
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    header.delete_prefix("Bearer ").strip.presence if header.start_with?("Bearer ")
  end

  def secure_match?(expected, provided)
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(expected),
      Digest::SHA256.hexdigest(provided)
    )
  end
end
