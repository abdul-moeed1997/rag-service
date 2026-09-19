# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :tenant

  TOKEN_PREFIX = "rag_"
  PREFIX_LENGTH = 8

  attr_accessor :raw_token

  validates :name, presence: true
  validates :token_prefix, presence: true
  validates :token_digest, presence: true, uniqueness: true

  def self.generate_for!(tenant:, name:)
    raw = "#{TOKEN_PREFIX}#{SecureRandom.hex(24)}"
    create!(
      tenant: tenant,
      name: name,
      token_prefix: raw[0, TOKEN_PREFIX.length + PREFIX_LENGTH],
      token_digest: digest(raw),
      raw_token: raw
    )
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    prefix = raw_token[0, TOKEN_PREFIX.length + PREFIX_LENGTH]
    candidates = where(token_prefix: prefix)
    key = candidates.find { |k| ActiveSupport::SecurityUtils.secure_compare(k.token_digest, digest(raw_token)) }
    key&.touch(:last_used_at)
    key
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
