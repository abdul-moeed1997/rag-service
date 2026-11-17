# frozen_string_literal: true

require "test_helper"

class Documents::PaginatorTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(name: "Paginator Co")
  end

  test "returns a limited page with next cursor when more remain" do
    docs = 3.times.map do |i|
      Document.create!(
        tenant: @tenant,
        title: "Doc #{i}",
        content: "body #{i}",
        source_type: "text",
        status: "ready",
        created_at: Time.zone.parse("2026-01-01 12:00:0#{i}")
      )
    end

    page = Documents::Paginator.new(scope: Document.for_tenant(@tenant), limit: 2).call

    assert_equal 2, page[:records].size
    assert_equal [ docs[2].id, docs[1].id ], page[:records].map(&:id)
    assert page[:pagination][:has_more]
    assert_equal 2, page[:pagination][:limit]
    assert_equal Documents::Paginator.encode_cursor(docs[1]), page[:pagination][:next_cursor]
  end

  test "after cursor continues from previous page" do
    older = Document.create!(
      tenant: @tenant, title: "Older", content: "a", source_type: "text", status: "ready",
      created_at: Time.zone.parse("2026-01-01 10:00:00")
    )
    newer = Document.create!(
      tenant: @tenant, title: "Newer", content: "b", source_type: "text", status: "ready",
      created_at: Time.zone.parse("2026-01-01 11:00:00")
    )

    cursor = Documents::Paginator.encode_cursor(newer)
    page = Documents::Paginator.new(scope: Document.for_tenant(@tenant), after: cursor, limit: 10).call

    assert_equal [ older.id ], page[:records].map(&:id)
    assert_not page[:pagination][:has_more]
    assert_nil page[:pagination][:next_cursor]
  end

  test "rejects invalid cursor" do
    assert_raises(ArgumentError) do
      Documents::Paginator.new(scope: Document.for_tenant(@tenant), after: "not-a-cursor").call
    end
  end
end
