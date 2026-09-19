# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_key!
  end

  private

  def authenticate_api_key!
    raw = bearer_token
    @current_api_key = ApiKey.authenticate(raw)

    unless @current_api_key
      render json: { error: "unauthorized", message: "Invalid or missing API key" }, status: :unauthorized
    end
  end

  def current_tenant
    @current_api_key.tenant
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    return header.delete_prefix("Bearer ").strip if header.start_with?("Bearer ")

    request.headers["X-Api-Key"].presence
  end
end
