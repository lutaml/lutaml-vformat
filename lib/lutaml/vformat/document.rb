# frozen_string_literal: true

module Lutaml
  module Vformat
    # The parsed document: components as ordered property hashes, the
    # data carrier between the parser, the transform, and the adapter
    # (the FormatRegistry adapter face).
    class Document
      attr_reader :objects

      def initialize(objects = [], _options = {})
        @objects = objects
      end

      def self.parse(vobject_data, _options = {})
        component = nil
        objects = []
        Parser.new(vobject_data).parse.each do |line|
          case line.name
          when "BEGIN"
            component = { name: line.value, properties: {},
                          groups: {} }
          when "END"
            objects << component
            component = nil
          else
            next unless component

            properties = if line.group
                           component[:groups]
                         else
                           component[:properties]
                         end
            properties[line.name] ||= []
            properties[line.name] << {
              value: line.value,
              params: line.params,
              group: line.group,
            }
          end
        end
        new(objects)
      end

      def [](key)
        @objects[key]
      end

      def []=(key, value)
        @objects[key] = value
      end

      def to_h
        @objects
      end

      def map(&block)
        @objects.map(&block)
      end

      # Serialize: BEGIN/END wrappers, escaped property values with
      # parameters, group prefixes, and folded content lines.
      def to_vobject(*)
        components = @objects.map do |obj|
          ["BEGIN:#{obj[:name]}",
           *serialize_properties(obj),
           "END:#{obj[:name]}"].join("\n")
        end
        "#{components.join("\n\n")}\n"
      end

      private

      def serialize_properties(obj)
        obj[:properties].flat_map do |name, entries|
          serialize_entries(name, entries)
        end +
          (obj[:groups] || {}).flat_map do |name, entries|
            serialize_entries(name, entries)
          end
      end

      def serialize_entries(name, entries)
        entries.map do |entry|
          params = format_params(entry[:params])
          group_prefix = entry[:group] ? "#{entry[:group]}." : ""
          prop = "#{group_prefix}#{name.upcase}"
          prop = "#{prop};#{params}" unless params.empty?
          line = "#{prop}:#{Text.escape(entry[:value])}"
          Text.fold(line).join("\n")
        end
      end

      def format_params(params)
        (params || {}).filter_map do |key, value|
          formatted = value.is_a?(Array) ? value.join(",") : value
          next if formatted.nil? || formatted.to_s.empty?

          "#{key}=#{formatted}"
        end.join(";")
      end
    end

    # The FormatRegistry adapter face: parses format data into the
    # document carrier.
    class Adapter < Document; end
  end
end
