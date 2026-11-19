# frozen_string_literal: true

class OpenapiController < ApplicationController
  admit :public

  def show
    path = Rails.root.join("docs/openapi.yaml")
    send_file path, type: "application/yaml", disposition: "inline", filename: "openapi.yaml"
  end
end
