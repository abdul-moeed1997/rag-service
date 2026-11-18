# frozen_string_literal: true

module RequestIdTrackable
  extend ActiveSupport::Concern

  included do
    before_action :capture_request_id
    after_action :echo_request_id_header
  end

  private

  def capture_request_id
    Current.request_id = request.request_id
  end

  def echo_request_id_header
    response.set_header("X-Request-Id", Current.request_id) if Current.request_id.present?
  end
end
