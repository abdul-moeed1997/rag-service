require_relative "boot"

require "rails/all"

# Require the gems listed in the Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RagService
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Active Record encryption (tenant webhook secrets).
    # Production: set both ENV vars (or `active_record_encryption` in credentials).
    # Development and test fall back to fixed, non-secret keys.
    encryption_primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence
    encryption_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence
    unless Rails.env.production?
      encryption_primary_key ||= "development-only-primary-key-0000000"
      encryption_salt ||= "development-only-derivation-salt-000"
    end
    config.active_record.encryption.primary_key = encryption_primary_key if encryption_primary_key
    config.active_record.encryption.key_derivation_salt = encryption_salt if encryption_salt
    # Rows written before encryption was turned on stay readable.
    # Run `bin/rails rag:encrypt_webhook_secrets` once to encrypt them.
    config.active_record.encryption.support_unencrypted_data = true
  end
end
