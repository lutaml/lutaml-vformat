# frozen_string_literal: true

module Lutaml
  module Vformat
    # The FormatRegistry transformer face: model <-> document
    # conversion driven by the model's vobject mapping.
    class Transform < Lutaml::Model::Transform
      def self.data_to_model(context, data, _format, _options = {})
        new(context).data_to_model(data)
      end

      def self.model_to_data(context, model, _format, _options = {})
        new(context).model_to_data(model)
      end

      def data_to_model(data)
        mappings = context.mappings_for(:vobject)
        instance = model_class.new
        component = data[0]
        return instance unless component

        mappings.mappings.each do |mapping|
          attribute = attributes[mapping.to]
          next unless attribute

          value = read_mapping(mapping, attribute, component)
          instance.public_send(:"#{mapping.to}=", value) unless value.nil?
        end

        instance
      end

      def model_to_data(model)
        mappings = context.mappings_for(:vobject)
        properties = {}

        mappings.mappings.each do |mapping|
          attribute = attributes[mapping.to]
          next unless attribute

          value = model.public_send(mapping.to)
          next if value.nil?

          entries = serialize_mapping(mapping, attribute, value)
          properties[mapping.name.to_s.upcase] = entries unless entries.empty?
        end

        Document.new([{ name: mappings.root_name || "VCARD",
                        properties: properties, groups: {} }])
      end

      private

      def read_mapping(mapping, attribute, component)
        entries = component[:properties][mapping.name.to_s]
        return nil unless entries

        if mapping.component?
          entries
        elsif mapping.structured?
          structured_from_entries(entries, attribute)
        else
          entries_from_entries(entries, attribute, mapping)
        end
      end

      def entries_from_entries(entries, attribute, mapping)
        if attribute.collection?
          entries.map { |entry| entry_to_value(entry, attribute, mapping) }
        else
          entry_to_value(entries.first, attribute, mapping)
        end
      end

      # A single parsed entry becomes the attribute's value: nested
      # serializable types consume their own vobject mapping (value +
      # parameters), everything else parses through the value-type
      # factory honoring the VALUE parameter.
      def entry_to_value(entry, attribute, _mapping)
        type_class = attribute.type.is_a?(Class) ? attribute.type : nil
        nested = type_class&.include?(Lutaml::Model::Serialize)

        if nested && type_class.mappings_for(:vobject)
          nested_from_entry(type_class, entry)
        else
          value_type = entry[:params]["VALUE"]
          VobjectPropertyValue.parse(entry[:value], value_type)
        end
      end

      def nested_from_entry(type_class, entry)
        nested_mapping = type_class.mappings_for(:vobject)
        instance = type_class.new
        value_type = entry[:params]["VALUE"]
        register = nested_register(type_class)

        nested_mapping.mappings.each do |rule|
          attribute = type_class.attributes(register)[rule.to]
          next unless attribute

          value = if rule.is_a?(FieldMappingRule)
                    field_from_value(entry[:value], rule)
                  elsif rule.name == :value
                    VobjectPropertyValue.parse(entry[:value], value_type)
                  else
                    param = entry[:params][rule.name.to_s.upcase]
                    param.nil? ? nil : param
                  end
          instance.public_send(:"#{rule.to}=", value) unless value.nil?
        end

        instance
      end

      def field_from_value(value, rule)
        return nil if value.nil?

        fields = value.split(";")
        field = fields[rule.name]
        Text.unescape(field) if field
      end

      def structured_from_entries(entries, attribute)
        first = entries.first
        return nil unless first&.dig(:value)

        type_class = attribute.type
        value_fields = first[:value].split(";")
        instance = type_class.new
        register = nested_register(type_class)

        type_class.mappings_for(:vobject).mappings.each do |rule|
          attribute = type_class.attributes(register)[rule.to]
          next unless attribute

          raw = value_fields[rule.name]
          unless raw.nil?
            instance.public_send(:"#{rule.to}=",
                                 Text.unescape(raw))
          end
        end

        instance
      end

      def nested_register(type_class)
        Lutaml::Model::Register.resolve_for_child(type_class, lutaml_register)
      end

      def serialize_mapping(mapping, attribute, value)
        if mapping.structured?
          [{ value: serialize_structured(value, attribute) }]
        elsif attribute.collection?
          Array(value).map { |item| serialize_entry(attribute, item) }
        else
          [serialize_entry(attribute, value)].compact
        end
      end

      def serialize_structured(value, attribute)
        nested_mapping = attribute.type.mappings_for(:vobject)
        arr = Array.new(nested_mapping.field_set[:count])

        nested_mapping.mappings.each do |rule|
          arr[rule.name] = value.public_send(rule.to)
        end

        arr.map(&:to_s).join(";")
      end

      def serialize_entry(attribute, item)
        type_class = attribute.type.is_a?(Class) ? attribute.type : nil
        nested = type_class&.include?(Lutaml::Model::Serialize)

        if nested && type_class.mappings_for(:vobject)
          nested_to_entry(type_class, item)
        else
          { value: serialize_scalar(item) }
        end
      end

      def nested_to_entry(type_class, item)
        nested_mapping = type_class.mappings_for(:vobject)
        params = {}
        value = nil
        register = nested_register(type_class)

        nested_mapping.mappings.each do |rule|
          attr = type_class.attributes(register)[rule.to]
          next unless attr

          attr_value = item.public_send(rule.to)
          next if attr_value.nil?

          if rule.name == :value
            value = serialize_scalar(attr_value)
          else
            params[rule.name.to_s.upcase] = attr_value.to_s
          end
        end

        { value: value.to_s, params: params }
      end

      def serialize_scalar(value)
        if value.respond_to?(:to_vobject)
          value.to_vobject
        elsif value.is_a?(VobjectValueType::Base)
          value.value
        else
          value.to_s
        end
      end
    end
  end
end
