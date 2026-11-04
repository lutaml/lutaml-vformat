# frozen_string_literal: true

require "uri"
require_relative "value/base"
require_relative "value/text"
require_relative "value/scalar"
require_relative "value/date_and_or_time"

module Lutaml
  module Vformat
    # The vObject value types.
    module Value
      TYPES = {
        text: Text,
        uri: Uri,
        binary: Binary,
        boolean: Boolean,
        integer: Integer,
        float: Float,
        utc_offset: UtcOffset,
        language_tag: LanguageTag,
        date_and_or_time: DateAndOrTime,
      }.freeze

      # RFC 6350 VALUE= parameter spellings that are not just TYPES keys.
      ALIASES = {
        "date" => :date_and_or_time, "time" => :date_and_or_time,
        "date-time" => :date_and_or_time,
        "date-and-or-time" => :date_and_or_time,
        "timestamp" => :date_and_or_time,
        "utc-offset" => :utc_offset, "language-tag" => :language_tag
      }.freeze

      # @param name [Symbol, String] :integer, "integer", "language-tag", ...
      def self.for(name)
        key = name.to_s.downcase
        TYPES[key.tr("-",
                     "_").to_sym] || (ALIASES[key] && TYPES[ALIASES[key]]) ||
          raise(ArgumentError, "unknown vObject value type: #{name.inspect}")
      end
    end
  end
end
