# frozen_string_literal: true

module ApiKeys
  class Mint
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(name:, tenant_id: nil, tenant_name: nil, **extras)
      @name = name.to_s.strip
      @tenant_id = tenant_id
      @tenant_name = tenant_name.to_s.strip.presence
      @webhook_url_set = extras.key?(:tenant_webhook_url)
      @webhook_secret_set = extras.key?(:tenant_webhook_secret)
      @tenant_webhook_url = extras[:tenant_webhook_url].to_s.strip.presence
      @tenant_webhook_secret = extras[:tenant_webhook_secret].to_s.strip.presence
    end

    def call
      raise Error, "name is required" if @name.blank?

      tenant = resolve_tenant!
      apply_webhook_settings!(tenant)
      key = ApiKey.generate_for!(tenant: tenant, name: @name)
      { tenant: tenant, api_key: key }
    end

    private

    def resolve_tenant!
      if @tenant_id.present?
        Tenant.find(@tenant_id)
      elsif @tenant_name.present?
        Tenant.find_or_create_by!(name: @tenant_name)
      else
        raise Error, "tenant_id or tenant_name is required"
      end
    end

    def apply_webhook_settings!(tenant)
      attrs = {}
      attrs[:webhook_url] = @tenant_webhook_url if @webhook_url_set
      attrs[:webhook_secret] = @tenant_webhook_secret if @webhook_secret_set
      return if attrs.empty?

      tenant.update!(attrs)
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.join(", ")
    end
  end
end
