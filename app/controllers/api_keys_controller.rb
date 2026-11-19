# frozen_string_literal: true

class ApiKeysController < ApplicationController
  admit :operator

  def index
    tenant = Tenant.find(params.require(:tenant_id))
    keys = tenant.api_keys.order(created_at: :desc)
    render json: { api_keys: keys.map { |key| serialize(key) } }
  end

  def create
    result = ApiKeys::Mint.call(**mint_params)
    key = result[:api_key]
    tenant = result[:tenant]

    render json: {
      api_key: serialize(key).merge(
        tenant_name: tenant.name,
        tenant_webhook_url: tenant.webhook_url,
        token: key.raw_token
      )
    }, status: :created
  rescue ApiKeys::Mint::Error => e
    render json: { error: "invalid", message: e.message }, status: :unprocessable_entity
  end

  # Revokes the key. It stops working immediately; the record is kept for audit.
  def destroy
    key = ApiKey.find(params[:id])
    key.revoke!
    render json: { api_key: serialize(key) }
  end

  private

  def mint_params
    params.require(:api_key).permit(
      :name,
      :tenant_id,
      :tenant_name,
      :tenant_webhook_url,
      :tenant_webhook_secret,
      :expires_at
    ).to_h.symbolize_keys
  end

  def serialize(key)
    {
      id: key.id,
      name: key.name,
      tenant_id: key.tenant_id,
      token_prefix: key.token_prefix,
      active: key.active?,
      last_used_at: key.last_used_at,
      expires_at: key.expires_at,
      revoked_at: key.revoked_at,
      created_at: key.created_at
    }
  end
end
