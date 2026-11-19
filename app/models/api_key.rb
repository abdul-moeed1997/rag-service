# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :tenant

  TOKEN_PREFIX = "rag_"
  PREFIX_LENGTH = 8
  # last_used_at is a coarse signal; avoid a database write on every request.
  LAST_USED_RESOLUTION = 5.minutes

  attr_accessor :raw_token

  validates :name, presence: true
  validates :token_prefix, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> {
    where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  def self.generate_for!(tenant:, name:, expires_at: nil)
    raw = "#{TOKEN_PREFIX}#{SecureRandom.hex(24)}"
    create!(
      tenant: tenant,
      name: name,
      expires_at: expires_at,
      token_prefix: raw[0, TOKEN_PREFIX.length + PREFIX_LENGTH],
      token_digest: digest(raw),
      raw_token: raw
    )
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    prefix = raw_token[0, TOKEN_PREFIX.length + PREFIX_LENGTH]
    digest = digest(raw_token)
    key = active.where(token_prefix: prefix).find do |candidate|
      ActiveSupport::SecurityUtils.secure_compare(candidate.token_digest, digest)
    end
    key&.record_use!
    key
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at.future?)
  end

  def revoke!
    update!(revoked_at: Time.current) if revoked_at.nil?
  end

  def record_use!
    return if last_used_at && last_used_at > LAST_USED_RESOLUTION.ago

    update_column(:last_used_at, Time.current)
  end
end
