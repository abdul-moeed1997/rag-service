# frozen_string_literal: true

require "test_helper"
require "rake"

class RagMintApiKeyTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks
    Rake::Task["rag:mint_api_key"].reenable
  end

  test "rake task creates tenant and prints raw token" do
    output = capture_io do
      Rake::Task["rag:mint_api_key"].invoke("Task Tenant", "cli")
    end.first

    assert_match(/Created tenant=Task Tenant/, output)
    assert_match(/api_key=rag_/, output)
    assert_match(/will not be shown again/, output)
    assert Tenant.exists?(name: "Task Tenant")
    assert ApiKey.joins(:tenant).exists?(tenants: { name: "Task Tenant" }, name: "cli")
  end
end
