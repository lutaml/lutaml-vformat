# frozen_string_literal: true

module Lutaml
  module Vformat
    # Components to models.
    class ModelReader
      include ModelSupport

      def initialize(register)
        @register = register
      end

      def component(klass, component)
        mapping = klass.mappings_for(:vobject)
        attrs = attrs_of(klass)
        values = {}
        values.update(property_values(mapping, attrs, component))
        values.update(child_values(mapping, attrs, component))
        build(klass, values)
      end

      private

      def build(klass, values)
        klass.new(values.reject { |_, v| v.nil? || v == [] })
      end

      def pick(attribute, list)
        attribute.collection? ? list : list.first
      end

      def property_values(mapping, attrs, component)
        mapping.rules(:property).to_h do |rule|
          attribute = attrs.fetch(rule.to)
          [rule.to, read_properties(attribute, rule, component)]
        end
      end

      def child_values(mapping, attrs, component)
        mapping.rules(:component).to_h do |rule|
          attribute = attrs.fetch(rule.to)
          children = component.components_named(rule.name).map do |child|
            component(type_of(attribute), child)
          end
          [rule.to, pick(attribute, children)]
        end
      end

      def read_properties(attribute, rule, component)
        type = type_of(attribute)
        list = component.properties_named(rule.name).map do |prop|
          if property_model?(type)
            property_model(type, prop)
          else
            leaf(type, prop, rule.value_type)
          end
        end
        pick(attribute, list)
      end

      def leaf(type, prop, value_type)
        Codec.read(type, prop.value, value_type: value_type)
      end

      def property_model(klass, prop)
        mapping = klass.mappings_for(:vobject)
        attrs = attrs_of(klass)
        values = value_and_group(mapping, attrs, prop)
        values.update(params(mapping, attrs, prop))
        values.update(fields(mapping, attrs, prop))
        build(klass, values)
      end

      def value_and_group(mapping, attrs, prop)
        values = mapping.rules(:value).to_h do |rule|
          type = type_of(attrs.fetch(rule.to))
          [rule.to, leaf(type, prop, rule.value_type)]
        end
        mapping.rules(:group).each { |rule| values[rule.to] = prop.group }
        values
      end

      def params(mapping, attrs, prop)
        mapping.rules(:param).to_h do |rule|
          attribute = attrs.fetch(rule.to)
          type = type_of(attribute)
          list = prop.param_values(rule.name).map do |text|
            Codec.read_param(type, text, value_type: rule.value_type)
          end
          [rule.to, pick(attribute, list)]
        end
      end

      def fields(mapping, attrs, prop)
        rules = mapping.rules(:field)
        return {} if rules.empty?

        slots = Structured.split_raw(prop.value)
        rules.to_h do |rule|
          attribute = attrs.fetch(rule.to)
          [rule.to, pick(attribute, field_values(attribute, rule, slots))]
        end
      end

      def field_values(attribute, rule, slots)
        type = type_of(attribute)
        # An empty field is no value; an empty item inside a list is kept.
        values = Array(slots[rule.name])
        values = [] if values == [""]
        values.map do |text|
          Codec.read(type, text, value_type: rule.value_type)
        end
      end
    end
  end
end
