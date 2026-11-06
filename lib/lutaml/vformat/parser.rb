# frozen_string_literal: true

module Lutaml
  module Vformat
    # A single parsed content line: the group prefix, the property or
    # component name, its parameters, and the value.
    class ContentLine
      attr_reader :group, :name, :params, :value

      def initialize(group:, name:, params:, value:)
        @group = group
        @name = name
        @params = params
        @value = value
      end
    end

    # Line-based vObject content parser (RFC 6350 §3.3 syntax).
    #
    # Parsing unfolds first (Text.unfold), so folded input is handled
    # transparently. Property lines carry an optional group prefix
    # (`item1.TEL:…`), semicolon-separated parameters — quoted
    # parameter values may contain semicolons and commas — and the
    # value after the first non-quoted colon. Property values are
    # unescaped; component lines (BEGIN/END) carry the component name
    # verbatim.
    class Parser
      BEGIN_PREFIX = "BEGIN:"
      END_PREFIX = "END:"

      def initialize(data)
        @data = data.to_s
      end

      # Returns the parsed content lines. Component boundaries are
      # emitted as ContentLine entries with name BEGIN/END and the
      # component name as the value, in document order.
      def parse
        lines = Text.unfold(@data.lines.map(&:chomp))
        lines.filter_map { |line| parse_line(line) }
      end

      private

      def parse_line(line)
        return nil if line.empty?

        if line.start_with?(BEGIN_PREFIX)
          return ContentLine.new(group: nil, name: "BEGIN", params: {},
                                 value: line[BEGIN_PREFIX.length..])
        end
        if line.start_with?(END_PREFIX)
          return ContentLine.new(group: nil, name: "END", params: {},
                                 value: line[END_PREFIX.length..])
        end

        parse_property_line(line)
      end

      def parse_property_line(line)
        prop_part, value = split_value(line)
        return nil unless value

        group, name, params = parse_name_section(prop_part)
        ContentLine.new(group: group, name: name, params: params,
                        value: Text.unescape(value))
      end

      # Split at the first colon outside double-quoted segments.
      def split_value(line)
        quoted = false
        line.each_char.with_index do |char, index|
          quoted = !quoted if char == '"'
          next if quoted
          next unless char == ":"

          return [line[0...index], line[(index + 1)..]]
        end
        nil
      end

      def parse_name_section(prop_part)
        segments = split_on_semicolons(prop_part)
        full_name = segments.shift
        group, name = split_group(full_name)
        [group, name, parse_params(segments)]
      end

      # A group prefix is everything before the first period; names
      # themselves may contain periods only in x-name extensions, so
      # the split takes the FIRST period (RFC 6350 §3.3 grammar).
      def split_group(full_name)
        if (m = full_name.match(/\A([^.]+)\.([^.]+)\z/))
          [m[1].downcase, m[2].downcase]
        else
          [nil, full_name.downcase]
        end
      end

      # Split on semicolons outside double-quoted segments.
      def split_on_semicolons(text)
        segments = []
        current = +""
        quoted = false
        text.each_char do |char|
          quoted = !quoted if char == '"'
          if char == ";" && !quoted
            segments << current
            current = +""
          else
            current << char
          end
        end
        segments << current
      end

      def parse_params(segments)
        segments.each_with_object({}) do |segment, params|
          key, value = segment.split("=", 2)
          next if value.nil?

          quoted = value.start_with?('"') && value.end_with?('"')
          params[key.strip.upcase] = if quoted
                                       value[1..-2]
                                     elsif value.include?(",")
                                       value.split(",")
                                     else
                                       value
                                     end
        end
      end
    end
  end
end
