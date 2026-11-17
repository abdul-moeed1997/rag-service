# frozen_string_literal: true

module RagService
  # Emits one JSON object per log line for production/ops collectors.
  class JsonLogFormatter < Logger::Formatter
    def call(severity, time, progname, msg)
      payload = {
        level: severity,
        time: time.utc.iso8601(3),
        progname: progname,
        message: msg2str(msg).strip
      }
      payload.compact!
      "#{payload.to_json}\n"
    end
  end
end
