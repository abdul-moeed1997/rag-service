# frozen_string_literal: true

module Embeddings
  # Worth retrying: timeouts, connection failures, 429 and 5xx responses.
  class TransientError < Error; end
end
