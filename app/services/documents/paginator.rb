# frozen_string_literal: true

module Documents
  class Paginator
    def initialize(scope:, after: nil, limit: nil)
      @scope = scope
      @after = after
      @limit = normalize_limit(limit)
    end

    def self.default_limit
      ENV.fetch("DOCUMENTS_DEFAULT_LIMIT", "20").to_i
    end

    def self.max_limit
      ENV.fetch("DOCUMENTS_MAX_LIMIT", "100").to_i
    end

    def call
      records = page_scope.limit(@limit + 1).to_a
      has_more = records.size > @limit
      records = records.first(@limit)

      {
        records: records,
        pagination: {
          next_cursor: has_more && records.last ? self.class.encode_cursor(records.last) : nil,
          has_more: has_more,
          limit: @limit
        }
      }
    end

    def self.decode_cursor(cursor)
      created_at_s, id_s = Base64.urlsafe_decode64(cursor.to_s).split("|", 2)
      raise ArgumentError, "invalid cursor" if created_at_s.blank? || id_s.blank?

      created_at = Time.zone.parse(created_at_s)
      raise ArgumentError, "invalid cursor" if created_at.nil?

      [ created_at, Integer(id_s) ]
    rescue ArgumentError, TypeError
      raise ArgumentError, "invalid cursor"
    end

    def self.encode_cursor(record)
      Base64.urlsafe_encode64("#{record.created_at.iso8601(6)}|#{record.id}")
    end

    private

    def page_scope
      scoped = @scope.order(created_at: :desc, id: :desc)
      return scoped if @after.blank?

      created_at, id = self.class.decode_cursor(@after)
      scoped.where("(created_at, id) < (?, ?)", created_at, id)
    end

    def normalize_limit(limit)
      default = self.class.default_limit
      value = limit.presence&.to_i || default
      value = default if value < 1
      [ value, self.class.max_limit ].min
    end
  end
end
