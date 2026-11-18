# frozen_string_literal: true

namespace :retrieval do
  desc "Run retrieval eval harness (recall@k for vector and hybrid). Optional GOLDEN=path"
  task eval: :environment do
    path = ENV.fetch("GOLDEN", Rails.root.join("eval/golden.json").to_s)
    ENV["EMBEDDING_PROVIDER"] ||= "fake"

    report = Retrieval::Eval::Runner.new(golden_path: path).call

    puts "Retrieval eval (#{path})"
    report.fetch(:modes).each do |mode, stats|
      puts "  mode=#{mode} queries=#{stats[:queries]}"
      stats.fetch(:recall_at_k).each do |k, score|
        puts "    recall@#{k}=#{score}"
      end
    end
  end
end
