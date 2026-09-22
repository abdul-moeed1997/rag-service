# frozen_string_literal: true

namespace :rag do
  desc "Mint a tenant API key. Usage: bin/rails \"rag:mint_api_key[Tenant Name,key-name]\""
  task :mint_api_key, [ :tenant_name, :key_name ] => :environment do |_t, args|
    tenant_name = args[:tenant_name].to_s.strip
    key_name = args[:key_name].to_s.strip.presence || "default"

    if tenant_name.blank?
      abort "Usage: bin/rails \"rag:mint_api_key[Tenant Name,key-name]\""
    end

    result = ApiKeys::Mint.call(name: key_name, tenant_name: tenant_name)
    tenant = result[:tenant]
    key = result[:api_key]

    puts "Created tenant=#{tenant.name} (id=#{tenant.id}) api_key_name=#{key.name} api_key=#{key.raw_token}"
    puts "Store this key; it will not be shown again."
  rescue ApiKeys::Mint::Error => e
    abort e.message
  end
end
