# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Authenticatable

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not_found", message: "Resource not found" }, status: :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: "invalid", message: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
  end
end
