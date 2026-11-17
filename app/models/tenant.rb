# frozen_string_literal: true

class Tenant < ApplicationRecord
  has_many :api_keys, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :chunks, dependent: :destroy

  validates :name, presence: true
  validates :webhook_url, format: { with: /\Ahttps?:\/\/.+\z/i, message: "must be an http(s) URL" }, allow_blank: true
end
