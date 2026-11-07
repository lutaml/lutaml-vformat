# frozen_string_literal: true

module Lutaml
  module Vformat
    # Components to text: CRLF line endings, lines folded at 75 octets.
    class Writer
      QUOTE_NEEDED = /[:;,]/

      def self.write(components)
        new.write(components)
      end

      def write(components)
        components.flat_map { |c| component_lines(c) }
          .map { |line| Folding.fold(line) + Folding::CRLF }.join
      end

      private

      def component_lines(component)
        [
          "BEGIN:#{component.name}",
          *component.properties.map { |p| property_line(p) },
          *component.components.flat_map { |c| component_lines(c) },
          "END:#{component.name}",
        ]
      end

      def property_line(property)
        head = [property.group && "#{property.group}.", property.name].join
        params = property.params.map { |k, v| ";#{k}=#{param_values(k, v)}" }
        "#{head}#{params.join}:#{property.value}"
      end

      def param_values(name, values)
        values.map { |v| param_value(name, v) }.join(",")
      end

      def param_value(name, value)
        if value.match?(/["\r\n]/)
          raise SerializeError,
                "parameter #{name} value #{value.inspect} contains a " \
                "double quote or line break, which cannot be written"
        end

        value.match?(QUOTE_NEEDED) ? "\"#{value}\"" : value
      end
    end
  end
end
