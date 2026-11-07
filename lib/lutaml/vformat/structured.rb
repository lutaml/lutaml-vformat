# frozen_string_literal: true

module Lutaml
  module Vformat
    # Structured values: fields separated by ";", each field holding one or
    # more values separated by ",". Separators are only those not escaped
    # with a backslash.
    module Structured
      module_function

      # @return [Array<Array<String>>] fields, each an array of unescaped values
      def split(raw)
        split_raw(raw).map { |field| field.map { |v| Escaping.unescape(v) } }
      end

      # Like #split, but values stay in wire (escaped) form.
      def split_raw(raw)
        split_unescaped(raw, ";").map { |field| split_unescaped(field, ",") }
      end

      # Joins fields of already-escaped values.
      def join_raw(fields)
        fields.map { |field| Array(field).join(",") }.join(";")
      end

      # @param fields [Array<String, Array<String>, nil>]
      def join(fields)
        fields.map do |field|
          Array(field).map { |v| Escaping.escape(v) }.join(",")
        end.join(";")
      end

      # Splits on +separator+ except where a backslash escapes it; the
      # backslashes stay in the parts.
      def split_unescaped(raw, separator)
        parts = [+""]
        raw.scan(/\\.|./m) do |token|
          token == separator ? parts << +"" : parts.last << token
        end
        parts
      end
    end
  end
end
