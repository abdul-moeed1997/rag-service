# frozen_string_literal: true

require "test_helper"

class Retrieval::Eval::MetricsTest < ActiveSupport::TestCase
  test "recall_at_k is 1 when all relevant ids are in the top-k" do
    assert_in_delta 1.0, Retrieval::Eval::Metrics.recall_at_k([ 1, 2, 3 ], [ 2 ], 3)
  end

  test "recall_at_k is partial when only some relevant ids are retrieved" do
    assert_in_delta 0.5, Retrieval::Eval::Metrics.recall_at_k([ 1, 9 ], [ 1, 2 ], 2)
  end

  test "recall_at_k is 0 when none of the relevant ids are retrieved" do
    assert_in_delta 0.0, Retrieval::Eval::Metrics.recall_at_k([ 9, 8 ], [ 1, 2 ], 2)
  end

  test "recall_at_k is 0 when relevant set is empty" do
    assert_in_delta 0.0, Retrieval::Eval::Metrics.recall_at_k([ 1 ], [], 1)
  end

  test "mean_recall_at_k averages query scores" do
    assert_in_delta 0.75, Retrieval::Eval::Metrics.mean_recall_at_k([ 1.0, 0.5 ])
  end
end
