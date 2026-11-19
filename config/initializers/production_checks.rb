# frozen_string_literal: true

# Fail at boot, with a clear message, instead of serving bad results later.
# Skipped during image builds (SECRET_KEY_BASE_DUMMY).
Rails.application.config.after_initialize do
  next unless Rails.env.production?
  next if ENV["SECRET_KEY_BASE_DUMMY"].present?

  problems = []

  provider = ENV.fetch("EMBEDDING_PROVIDER", "fake")
  if provider == "fake" && ENV["ALLOW_FAKE_EMBEDDINGS"] != "true"
    problems << "EMBEDDING_PROVIDER is \"fake\": search results would be meaningless. " \
                "Set it to openai, voyage, or local (or ALLOW_FAKE_EMBEDDINGS=true for a demo)."
  elsif Embeddings::Client::PROVIDERS.exclude?(provider)
    problems << "EMBEDDING_PROVIDER \"#{provider}\" is not one of: #{Embeddings::Client::PROVIDERS.join(', ')}."
  end

  required_for_provider = {
    "openai" => "OPENAI_API_KEY", "voyage" => "VOYAGE_API_KEY", "local" => "EMBEDDING_BASE_URL"
  }[provider]
  if required_for_provider && ENV[required_for_provider].blank?
    problems << "EMBEDDING_PROVIDER is \"#{provider}\" but #{required_for_provider} is not set."
  end

  encryption_ready =
    begin
      encryption = ActiveRecord::Encryption.config
      encryption.primary_key.present? && encryption.key_derivation_salt.present?
    rescue ActiveRecord::Encryption::Errors::Configuration
      false
    end
  unless encryption_ready
    problems << "Active Record encryption keys are missing. Set ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY and " \
                "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT (generate with `bin/rails db:encryption:init`)."
  end

  raise "Refusing to boot in production:\n- #{problems.join("\n- ")}" if problems.any?
end
