# frozen_string_literal: true

namespace :retrieval do
  desc "Run retrieval eval harness (recall@k for vector and hybrid). Optional GOLDEN=path"
  task eval: :environment do
    path = ENV.fetch("GOLDEN", Rails.root.join("eval/golden.json").to_s)
    ENV["EMBEDDING_PROVIDER"] ||= "fake"

    report = Retrieval::Eval::Runner.new(golden_path: path).call

    puts "Retrieval eval (#{path})"
    puts "  embedding_model=#{report[:embedding_model]}"
    if report[:embedding_model].to_s.start_with?("fake:")
      puts "  NOTE: fake embeddings carry no meaning. These numbers check the plumbing, not search quality."
      puts "        Run with EMBEDDING_PROVIDER=openai|voyage|local to measure real recall."
    end
    report.fetch(:modes).each do |mode, stats|
      puts "  mode=#{mode} queries=#{stats[:queries]}"
      stats.fetch(:recall_at_k).each do |k, score|
        puts "    recall@#{k}=#{score}"
      end
    end
  end
end
