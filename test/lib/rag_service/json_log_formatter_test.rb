# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/rag_service/json_log_formatter")

class RagService::JsonLogFormatterTest < ActiveSupport::TestCase
  test "formats log lines as JSON with level time and message" do
    line = RagService::JsonLogFormatter.new.call("INFO", Time.utc(2026, 1, 2, 3, 4, 5), nil, "hello")
    payload = JSON.parse(line)

    assert_equal "INFO", payload["level"]
    assert_equal "2026-01-02T03:04:05.000Z", payload["time"]
    assert_equal "hello", payload["message"]
  end
end
