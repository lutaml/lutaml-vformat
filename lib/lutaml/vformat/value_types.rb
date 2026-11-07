# frozen_string_literal: true

require "base64"
require "uri"

module Lutaml
  module Vformat
    # vObject value types (RFC 6350 §4.3 / RFC 5545 §3.3 vocabulary).
    #
    # Each type wraps the wire string and validates it; the value the
    # wire carries is always the string, with typed accessors where the
    # vocabulary defines them. `element_type` records the position the
    # value was parsed from (property or parameter).
    module VobjectValueType
      class Base < Lutaml::Model::Type::Value
        attr_accessor :element_type

        def initialize(value)
          super
          @element_type = ValueType::PROPERTY_VALUE
        end

        def as_property_value
          @element_type = ValueType::PROPERTY_VALUE
          self
        end

        def as_parameter_value
          @element_type = ValueType::PARAMETER_VALUE
          self
        end

        def valid?
          true
        end

        def ==(other)
          other.is_a?(self.class) && @value == other.value
        end
      end

      class Text < Base
        def valid?
          @value.is_a?(String)
        end
      end

      # URI as defined in Section 3 of RFC 3986.
      class Uri < Base
        def valid?
          uri = URI.parse(@value)
          !!(uri.scheme && uri.host)
        rescue URI::InvalidURIError
          false
        end
      end

      class Binary < Base
        def valid?
          Base64.strict_encode64(Base64.strict_decode64(@value)) == @value
        rescue ArgumentError
          false
        end
      end

      # DATE, DATE-TIME, or DATE-AND-OR-TIME per RFC 6350 §4.3.4 — the
      # reduced-accuracy and truncated forms included.
      class IsoDateAndOrTime < Base
        attr_reader :type

        def initialize(value)
          super
          @type = detect_type(value)
        end

        def valid?
          @type == detect_type(@value)
        end

        private

        def detect_type(value)
          case value
          # Complete date-time, RFC 6350 §4.3.4: basic and extended
          # spellings, with optional UTC designator or offset.
          when /^\d{8}T\d{6}(Z|[+-]\d{4})?$/,
               /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(Z|[+-]\d{2}:\d{2})?$/,
               /^--\d{4}T\d{4}$/,
               /^---\d{2}T\d{2}$/,
               /^T\d{6}(Z|[+-]\d{4})?$/,
               /^T\d{4}$/,
               /^T\d{2}$/,
               /^T-\d{4}$/,
               /^T--\d{2}$/,
               /^T\d{2}:\d{2}(:\d{2})?(Z|[+-]\d{2}:\d{2})?$/
            :date_time
          when /^\d{8}$/,
               /^\d{6}$/,
               /^\d{4}$/,
               /^\d{4}-\d{2}$/,
               /^\d{4}-\d{2}-\d{2}$/,
               /^--\d{4}$/,
               /^---\d{2}$/
            :date
          else
            :text
          end
        end
      end

      class Boolean < Base
        VALID_VALUES = %w[TRUE FALSE true false].freeze

        def initialize(value)
          super(value.to_s.upcase)
        end

        def valid?
          VALID_VALUES.include?(@value)
        end

        # The RFC spells this a value TRANSFORM, not a predicate; the
        # `to_` prefix follows the Integer#to_i / Float#to_f pattern.
        # rubocop:disable Naming/PredicateMethod
        def to_bool
          @value.upcase == "TRUE"
        end
        # rubocop:enable Naming/PredicateMethod
      end

      class Integer < Base
        def valid?
          @value.to_s.match?(/^-?\d+$/)
        end

        def to_i
          @value.to_i
        end
      end

      class Float < Base
        def valid?
          @value.to_s.match?(/^-?\d+(\.\d+)?$/)
        end

        def to_f
          @value.to_f
        end
      end

      class UtcOffset < Base
        def valid?
          @value.match?(/^[+-]\d{4}$/)
        end

        def hours
          @value[1..2].to_i * (@value[0] == "-" ? -1 : 1)
        end

        def minutes
          @value[3..4].to_i * (@value[0] == "-" ? -1 : 1)
        end
      end

      # Language-Tag as defined in RFC 5646.
      class Language < Base
        def valid?
          @value.match?(/^[a-zA-Z]{2,3}(-[a-zA-Z]{2,3})?$/)
        end
      end
    end

    # Value-string factory: maps the VALUE parameter spelling to the
    # value class and stamps the position the value was read from.
    class VobjectPropertyValue
      VALUE_TYPE_MAPPING = {
        "URI" => VobjectValueType::Uri,
        "BINARY" => VobjectValueType::Binary,
        "BOOLEAN" => VobjectValueType::Boolean,
        "INTEGER" => VobjectValueType::Integer,
        "FLOAT" => VobjectValueType::Float,
        "UTC-OFFSET" => VobjectValueType::UtcOffset,
        "LANGUAGE-TAG" => VobjectValueType::Language,
        "DATE" => VobjectValueType::IsoDateAndOrTime,
        "DATE-TIME" => VobjectValueType::IsoDateAndOrTime,
        "DATE-AND-OR-TIME" => VobjectValueType::IsoDateAndOrTime,
      }.freeze

      def self.parse(value_str, value_type = nil,
                     element_type = ValueType::PROPERTY_VALUE)
        unless [ValueType::PROPERTY_VALUE,
                ValueType::PARAMETER_VALUE].include?(element_type)
          raise ArgumentError, "Invalid element type: #{element_type}"
        end

        value_class = value_type ? VALUE_TYPE_MAPPING[value_type.upcase] : nil
        value_class ||= VobjectValueType::Text
        value = value_class.new(value_str)
        value.element_type = element_type
        value
      end
    end
  end
end
