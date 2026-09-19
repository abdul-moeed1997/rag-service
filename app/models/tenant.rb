# frozen_string_literal: true

class Tenant < ApplicationRecord
  has_many :api_keys, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :chunks, dependent: :destroy

  validates :name, presence: true
end
