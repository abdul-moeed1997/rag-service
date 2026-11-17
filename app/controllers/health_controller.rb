# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :authenticate_api_key!
  skip_before_action :enforce_rate_limit!

  def show
    render json: { status: "ok" }
  end
end
