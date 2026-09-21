# frozen_string_literal: true

module ApiKeys
  class Mint
    class Error < StandardError; end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(name:, tenant_id: nil, tenant_name: nil)
      @name = name.to_s.strip
      @tenant_id = tenant_id
      @tenant_name = tenant_name.to_s.strip.presence
    end

    def call
      raise Error, "name is required" if @name.blank?

      tenant = resolve_tenant!
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
  end
end
