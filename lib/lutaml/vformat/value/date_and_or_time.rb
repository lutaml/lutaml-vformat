# frozen_string_literal: true

module Lutaml
  module Vformat
    module Value
      # RFC 6350 section 4.3.4 date-and-or-time (and the extended ISO 8601
      # spellings vCard 3.0 / iCalendar producers emit). The native value
      # keeps the exact text and classifies it.
      class DateAndOrTime < Base
        Instant = Struct.new(:kind, :text) do
          include Comparable

          def to_s
            text
          end

          def <=>(other)
            other.is_a?(Instant) ? text <=> other.text : nil
          end
        end

        MONTH = "(?<mo>0[1-9]|1[0-2])"
        DAY = "(?<dd>0[1-9]|[12]\\d|3[01])"
        HOUR = "(?<hh>[01]\\d|2[0-3])"
        MINUTE = "(?<mi>[0-5]\\d)"
        SECOND = "(?<ss>[0-5]\\d|60)"
        ZONE = "(?:Z|[+-](?:[01]\\d|2[0-3])(?::?[0-5]\\d)?)"
        YEAR = "\\d{4}"

        DATE_NOREDUC = [
          "#{YEAR}-#{MONTH}-#{DAY}", "#{YEAR}#{MONTH}#{DAY}",
          "--#{MONTH}-?#{DAY}", "---#{DAY}"
        ].join("|").freeze
        DATE = [
          DATE_NOREDUC, "#{YEAR}-#{MONTH}", YEAR, "--#{MONTH}"
        ].join("|").freeze
        TIME_NOTRUNC = "#{HOUR}(?::?#{MINUTE}(?::?#{SECOND})?)?#{ZONE}?".freeze
        TIME = [
          TIME_NOTRUNC, "-#{MINUTE}(?::?#{SECOND})?#{ZONE}?",
          "--#{SECOND}#{ZONE}?"
        ].join("|").freeze

        DATE_RE = /\A(?:#{DATE})\z/
        DATE_TIME_RE = /\A(?:#{DATE_NOREDUC})T(?:#{TIME_NOTRUNC})\z/
        TIME_RE = /\AT(?:#{TIME})\z/

        def self.native?(value)
          value.is_a?(Instant)
        end

        def self.parse(wire)
          kind = if DATE_TIME_RE.match?(wire) then :date_time
                 elsif DATE_RE.match?(wire) then :date
                 elsif TIME_RE.match?(wire) then :time
                 else invalid!("date-and-or-time", wire)
                 end
          Instant.new(kind, wire).freeze
        end

        def self.format(value)
          value.is_a?(Instant) ? value.text : parse(value.to_s).text
        end

        def self.serialize(value)
          value.nil? ? nil : format(value)
        end
      end
    end
  end
end
