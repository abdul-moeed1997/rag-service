# frozen_string_literal: true

module Retrieval
  module Eval
    class Runner
      DEFAULT_GOLDEN = Rails.root.join("eval/golden.json")
      K_VALUES = [ 1, 5, 10 ].freeze
      MODES = Retrieval::Search::MODES

      def initialize(golden_path: DEFAULT_GOLDEN, embeddings: Embeddings::Client.build)
        @golden_path = Pathname(golden_path)
        @embeddings = embeddings
      end

      def call
        payload = JSON.parse(@golden_path.read)
        tenant = Tenant.create!(name: "eval-#{SecureRandom.hex(4)}")
        title_to_id = ingest_documents(tenant, payload.fetch("documents"))
        search = Retrieval::Search.new(tenant: tenant, embeddings: @embeddings)

        report = { embedding_model: @embeddings.model_id, modes: {} }

        MODES.each do |mode|
          report[:modes][mode] = evaluate_mode(search, payload.fetch("queries"), title_to_id, mode)
        end

        report
      ensure
        tenant&.destroy!
      end

      private

      def ingest_documents(tenant, documents)
        title_to_id = {}

        documents.each do |row|
          doc = Document.create!(
            tenant: tenant,
            title: row.fetch("title"),
            content: row.fetch("content"),
            source_type: "text",
            status: "pending",
            namespace: Document::DEFAULT_NAMESPACE
          )
          Ingest::Pipeline.call(doc, embeddings: @embeddings)
          doc.reload
          raise "Ingest failed for #{doc.title}: #{doc.error_message}" unless doc.status == "ready"

          title_to_id[doc.title] = doc.id
        end

        title_to_id
      end

      def evaluate_mode(search, queries, title_to_id, mode)
        per_k = K_VALUES.index_with { |_k| [] }

        queries.each do |row|
          relevant_ids = row.fetch("relevant_titles").map { |title| title_to_id.fetch(title) }
          hits = search.call(query: row.fetch("query"), top_k: K_VALUES.max, mode: mode).hits
          retrieved_ids = hits.map { |hit| hit[:document_id] }

          K_VALUES.each do |k|
            per_k[k] << Metrics.recall_at_k(retrieved_ids, relevant_ids, k)
          end
        end

        {
          queries: queries.size,
          recall_at_k: per_k.transform_values { |scores| Metrics.mean_recall_at_k(scores).round(4) }
        }
      end
    end
  end
end
