# frozen_string_literal: true

class HealthController < ApplicationController
  admit :public

  # Readiness: can this process reach its database? (`/up` is plain liveness.)
  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render json: { status: "ok", database: "ok" }
  rescue StandardError => e
    Rails.logger.error("Health check failed: #{e.class}: #{e.message}")
    render json: { status: "unavailable", database: "error" }, status: :service_unavailable
  end
end
