# frozen_string_literal: true

require "test_helper"

class RequestIdTest < ActionDispatch::IntegrationTest
  setup do
    _tenant, @key = create_tenant_key("RequestId")
  end

  test "echoes client-provided X-Request-Id on responses" do
    get "/documents",
        headers: auth_for(@key).merge("X-Request-Id" => "client-trace-123"),
        as: :json

    assert_response :success
    assert_equal "client-trace-123", response.headers["X-Request-Id"]
  end

  test "generates X-Request-Id when client omits it" do
    get "/health"

    assert_response :success
    assert_predicate response.headers["X-Request-Id"], :present?
  end
end
