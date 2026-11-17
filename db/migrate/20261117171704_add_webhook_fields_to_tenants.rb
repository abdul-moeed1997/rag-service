# frozen_string_literal: true

class AddWebhookFieldsToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :webhook_url, :string
    add_column :tenants, :webhook_secret, :string
  end
end
