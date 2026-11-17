# frozen_string_literal: true

require "test_helper"
require "yaml"

class OpenapiTest < ActionDispatch::IntegrationTest
  test "serves OpenAPI 3 YAML" do
    get "/openapi.yaml"
    assert_response :success

    spec = YAML.safe_load(response.body)
    assert spec["openapi"].to_s.start_with?("3.")
    assert_equal "RAG Service API", spec.dig("info", "title")
    assert spec.dig("paths", "/documents")
    assert spec.dig("paths", "/query")
  end
end
