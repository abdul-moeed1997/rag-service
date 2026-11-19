# frozen_string_literal: true

require "test_helper"

class Chunking::SplitterTest < ActiveSupport::TestCase
  test "returns nothing for blank text" do
    assert_empty Chunking::Splitter.new(size: 50, overlap: 10).call("  \n ")
  end

  test "keeps short text as one chunk" do
    assert_equal [ "hello world" ], Chunking::Splitter.new(size: 50, overlap: 10).call("hello world")
  end

  test "never exceeds the chunk size" do
    text = Array.new(200) { |i| "word#{i}" }.join(" ")
    chunks = Chunking::Splitter.new(size: 80, overlap: 10).call(text)

    assert_operator chunks.size, :>, 1
    assert(chunks.all? { |chunk| chunk.length <= 80 })
  end

  test "does not cut words in half" do
    words = Array.new(120) { |i| "token#{i}" }
    chunks = Chunking::Splitter.new(size: 90, overlap: 20).call(words.join(" "))

    chunks.each do |chunk|
      chunk.split(" ").each { |piece| assert_includes words, piece }
    end
  end

  test "prefers to end a chunk at a sentence" do
    text = "#{'Alpha beta gamma delta. ' * 3}#{'Epsilon zeta eta theta. ' * 3}".strip
    chunks = Chunking::Splitter.new(size: 100, overlap: 0).call(text)

    assert_operator chunks.size, :>, 1
    assert(chunks.all? { |chunk| chunk.end_with?(".") })
  end

  test "prefers a paragraph break over a sentence break" do
    first = "One two three. Four five six. Seven eight nine."
    second = "Second paragraph starts here and keeps going for a while longer."
    chunks = Chunking::Splitter.new(size: 60, overlap: 0).call("#{first}\n\n#{second}")

    assert_equal first, chunks.first
  end

  test "covers all of the text and overlaps neighbours" do
    words = Array.new(150) { |i| "w#{i}" }
    chunks = Chunking::Splitter.new(size: 100, overlap: 30).call(words.join(" "))

    assert_equal words, chunks.flat_map { |chunk| chunk.split(" ") }.uniq
    assert_not_empty chunks[0].split(" ") & chunks[1].split(" ")
  end

  test "still makes progress on text with no whitespace" do
    chunks = Chunking::Splitter.new(size: 10, overlap: 2).call("x" * 35)

    assert(chunks.all? { |chunk| chunk.length <= 10 })
    assert_operator chunks.sum(&:length), :>=, 35
  end
end
