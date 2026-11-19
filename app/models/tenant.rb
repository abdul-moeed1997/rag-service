# frozen_string_literal: true

class Tenant < ApplicationRecord
  has_many :api_keys, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :chunks, dependent: :destroy

  encrypts :webhook_secret

  validates :name, presence: true
  validates :webhook_url, format: { with: /\Ahttps?:\/\/.+\z/i, message: "must be an http(s) URL" }, allow_blank: true
  validate :webhook_url_not_internal, if: -> { webhook_url.present? && webhook_url_changed? }

  private

  def webhook_url_not_internal
    return unless Webhooks::UrlGuard.obviously_internal?(webhook_url)

    errors.add(:webhook_url, "must not point at a private or loopback address")
  end
end
