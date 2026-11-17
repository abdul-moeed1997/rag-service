# frozen_string_literal: true

class OpenapiController < ApplicationController
  skip_before_action :authenticate_api_key!
  skip_before_action :enforce_rate_limit!

  def show
    path = Rails.root.join("docs/openapi.yaml")
    send_file path, type: "application/yaml", disposition: "inline", filename: "openapi.yaml"
  end
end
