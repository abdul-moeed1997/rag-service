# frozen_string_literal: true

require "test_helper"

class HybridQueryTest < ActionDispatch::IntegrationTest
  setup do
    _tenant, @key = create_tenant_key("HybridAPI")
  end

  test "query accepts hybrid mode and returns chunks" do
    perform_enqueued_jobs do
      post "/documents",
           params: {
             document: {
               title: "Hybrid",
               content: "docs mentioning xylophone42 recovery steps",
               source_type: "text"
             }
           },
           headers: auth_for(@key),
           as: :json
      assert_response :accepted
    end

    post "/query",
         params: { query: "xylophone42", top_k: 3, mode: "hybrid" },
         headers: auth_for(@key),
         as: :json
    assert_response :success

    body = response.parsed_body
    assert_equal "hybrid", body["mode"]
    assert(body.fetch("chunks").any? { |chunk| chunk["content"].include?("xylophone42") })
  end
end
