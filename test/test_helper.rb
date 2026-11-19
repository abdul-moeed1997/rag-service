ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDING_PROVIDER"] ||= "fake"

require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

# Webhook URL checks resolve DNS; tests never touch the network.
Webhooks::UrlGuard.resolver = ->(_host) { [ "93.184.216.34" ] }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    include ActiveJob::TestHelper
    include AuthHelpers
  end
end
