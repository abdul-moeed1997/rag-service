# frozen_string_literal: true

module Retrieval
  module Eval
    module Metrics
      module_function

      # Fraction of relevant document ids that appear in the top-k retrieved document ids.
      def recall_at_k(retrieved_document_ids, relevant_document_ids, k)
        relevant = Array(relevant_document_ids).uniq
        return 0.0 if relevant.empty?

        top = Array(retrieved_document_ids).first(k.to_i).uniq
        (top & relevant).size.to_f / relevant.size
      end

      def mean_recall_at_k(per_query_scores)
        values = Array(per_query_scores)
        return 0.0 if values.empty?

        values.sum.to_f / values.size
      end
    end
  end
end
