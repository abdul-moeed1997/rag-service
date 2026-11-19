# frozen_string_literal: true

class AddRevocationToApiKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :api_keys, :revoked_at, :datetime
    add_column :api_keys, :expires_at, :datetime
  end
end
