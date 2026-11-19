# frozen_string_literal: true

# Sends every error reported through Rails.error (unhandled job and request
# errors, plus explicit Rails.error.report calls) to the log as one line.
# To use an error tracker, subscribe its reporter here as well, e.g.
#   Rails.error.subscribe(Sentry::Rails::ErrorSubscriber.new)
class LogErrorSubscriber
  def report(error, handled:, severity:, context:, source: nil)
    Rails.logger.error(
      {
        event: "error_reported",
        error_class: error.class.name,
        message: error.message.to_s.truncate(500),
        handled: handled,
        severity: severity,
        source: source,
        context: context.except(:controller, :job).presence,
        backtrace: Array(error.backtrace).first(5)
      }.compact.to_json
    )
  end
end

Rails.error.subscribe(LogErrorSubscriber.new)
