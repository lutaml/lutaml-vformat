# frozen_string_literal: true

module Lutaml
  module Vformat
    # Models to components.
    class ModelWriter
      include ModelSupport

      def initialize(register)
        @register = register
      end

      def component(name, klass, model)
        mapping = klass.mappings_for(:vobject)
        attrs = attrs_of(klass)
        Component.new(
          name,
          properties: properties(mapping, attrs, model),
          components: children(mapping, attrs, model),
        )
      end

      private

      def properties(mapping, attrs, model)
        mapping.rules(:property).flat_map do |rule|
          attribute = attrs.fetch(rule.to)
          list_of(model.public_send(rule.to)).map do |value|
            property(rule, type_of(attribute), value)
          end
        end
      end

      def children(mapping, attrs, model)
        mapping.rules(:component).flat_map do |rule|
          type = type_of(attrs.fetch(rule.to))
          list_of(model.public_send(rule.to)).map do |child|
            component(rule.name, type, child)
          end
        end
      end

      def property(rule, type, value)
        return property_model(rule.name, type, value) if property_model?(type)

        Property.new(rule.name,
                     Codec.write(type, value, value_type: rule.value_type))
      end

      def property_model(name, klass, model)
        mapping = klass.mappings_for(:vobject)
        attrs = attrs_of(klass)
        group_rule = mapping.rules(:group).first
        Property.new(
          name, model_value(mapping, attrs, model),
          params: params(mapping, attrs, model),
          group: group_rule && model.public_send(group_rule.to)
        )
      end

      def params(mapping, attrs, model)
        mapping.rules(:param).each_with_object({}) do |rule, result|
          list = param_list(rule, attrs, model)
          result[rule.name] = list unless list.empty?
        end
      end

      def param_list(rule, attrs, model)
        type = type_of(attrs.fetch(rule.to))
        list_of(model.public_send(rule.to)).map do |v|
          Codec.write_param(type, v, value_type: rule.value_type)
        end
      end

      def model_value(mapping, attrs, model)
        fields = mapping.rules(:field)
        return fields_value(fields, attrs, model) unless fields.empty?

        rule = mapping.rules(:value).first
        value = rule && model.public_send(rule.to)
        return "" if value.nil?

        Codec.write(type_of(attrs.fetch(rule.to)), value,
                    value_type: rule.value_type)
      end

      def fields_value(rules, attrs, model)
        slots = Array.new(rules.map(&:name).max + 1) { [] }
        rules.each { |rule| slots[rule.name] = field_list(rule, attrs, model) }
        Structured.join_raw(slots)
      end

      def field_list(rule, attrs, model)
        type = type_of(attrs.fetch(rule.to))
        list_of(model.public_send(rule.to)).map do |v|
          Codec.write(type, v, value_type: rule.value_type)
        end
      end
    end
  end
end
