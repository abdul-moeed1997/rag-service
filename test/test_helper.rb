ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDING_PROVIDER"] ||= "fake"

require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    include ActiveJob::TestHelper
    include AuthHelpers
  end
end
