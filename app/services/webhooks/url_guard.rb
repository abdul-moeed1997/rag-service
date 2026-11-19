# frozen_string_literal: true

require "ipaddr"
require "resolv"

module Webhooks
  # Stops tenant webhooks from being aimed at this server's own network
  # (loopback, private ranges, cloud metadata addresses).
  #
  # Known limit: the host is resolved here and again by the HTTP client, so a
  # DNS answer that changes between the two lookups is not caught. Put egress
  # firewall rules in front of the job workers if that matters to you.
  class UrlGuard
    BLOCKED_RANGES = %w[
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
      172.16.0.0/12 192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
      ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8
    ].map { |range| IPAddr.new(range) }.freeze
    LOCAL_HOSTNAMES = %w[localhost localhost.localdomain].freeze

    class << self
      attr_writer :resolver

      def resolver
        @resolver || ->(host) { Resolv.getaddresses(host) }
      end

      def reset_resolver!
        @resolver = nil
      end

      # Full check, with DNS. Used right before delivery.
      def allowed?(url)
        host = host_for(url)
        return false if host.nil?
        return true if private_hosts_allowed?
        return false if local_hostname?(host)

        addresses = literal_ip(host) ? [ host ] : resolver.call(host)
        addresses.any? && addresses.none? { |address| blocked_address?(address) }
      rescue StandardError
        false
      end

      # Cheap check, no DNS. Used when a webhook URL is saved.
      def obviously_internal?(url)
        return false if private_hosts_allowed?

        host = host_for(url)
        return false if host.nil?

        local_hostname?(host) || (literal_ip(host) && blocked_address?(host)) || false
      end

      private

      def private_hosts_allowed?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch("WEBHOOK_ALLOW_PRIVATE_HOSTS", "false"))
      end

      def host_for(url)
        uri = URI.parse(url.to_s)
        return unless uri.is_a?(URI::HTTP) && uri.host.present?

        uri.host.delete_prefix("[").delete_suffix("]").downcase
      rescue URI::InvalidURIError
        nil
      end

      def local_hostname?(host)
        LOCAL_HOSTNAMES.include?(host) || host.end_with?(".localhost", ".internal", ".local")
      end

      def literal_ip(host)
        IPAddr.new(host)
      rescue IPAddr::Error
        nil
      end

      def blocked_address?(address)
        ip = IPAddr.new(address.to_s)
        ip = ip.native if ip.ipv4_mapped?
        BLOCKED_RANGES.any? { |range| range.family == ip.family && range.include?(ip) }
      rescue IPAddr::Error
        true
      end
    end
  end
end
