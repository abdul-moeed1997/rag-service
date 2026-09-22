# frozen_string_literal: true

class ApiKeysController < ApplicationController
  include OperatorAuthenticatable

  skip_before_action :authenticate_api_key!

  def create
    result = ApiKeys::Mint.call(**mint_params)
    key = result[:api_key]
    tenant = result[:tenant]

    render json: {
      api_key: {
        id: key.id,
        name: key.name,
        tenant_id: tenant.id,
        tenant_name: tenant.name,
        token: key.raw_token,
        token_prefix: key.token_prefix,
        created_at: key.created_at
      }
    }, status: :created
  rescue ApiKeys::Mint::Error => e
    render json: { error: "invalid", message: e.message }, status: :unprocessable_entity
  end

  private

  def mint_params
    params.require(:api_key).permit(:name, :tenant_id, :tenant_name).to_h.symbolize_keys
  end
end
