# frozen_string_literal: true

module OperatorAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_operator!
  end

  private

  def authenticate_operator!
    expected = ENV["OPERATOR_API_KEY"].to_s
    provided = operator_token.to_s

    unless expected.present? && provided.present? && operator_keys_match?(expected, provided)
      render json: { error: "unauthorized", message: "Invalid or missing operator API key" }, status: :unauthorized
    end
  end

  def operator_keys_match?(expected, provided)
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(expected),
      Digest::SHA256.hexdigest(provided)
    )
  end
  def operator_token
    header = request.headers["Authorization"].to_s
    return header.delete_prefix("Bearer ").strip if header.start_with?("Bearer ")

    request.headers["X-Operator-Key"].presence
  end
end
