# frozen_string_literal: true

if Tenant.none?
  tenant = Tenant.create!(name: "Default")
  key = ApiKey.generate_for!(tenant: tenant, name: "default")
  puts "Created tenant=#{tenant.name} api_key=#{key.raw_token}"
  puts "Store this key; it will not be shown again."
else
  puts "Tenants already exist; skipping seed."
end
