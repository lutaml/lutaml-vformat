# frozen_string_literal: true

module Lutaml
  module Vformat
    # The vobject mapping DSL:
    #
    #   vobject do
    #     type :component            # or :property
    #     component_root "VCARD"     # component wire name
    #     property_root "TEL"        # property wire name
    #     map_property "FN", to: :fn
    #     map_property "N", to: :n, type: :structured
    #     map_value to: :value       # property's own value
    #     map_field_set count: 5, item_type: :list
    #     map_field 0, to: :family   # structured field by index
    #   end
    class Mapping < Lutaml::Model::Mapping
      attr_reader :mappings

      def initialize
        super
        @mappings = []
        @component_root = nil
        @property_root = nil
        @element_type = nil
        @field_set = nil
        @finalized = false
      end

      def finalize(_mapper_class)
        @finalized = true
      end

      def finalized?
        @finalized
      end

      def component_root(name = nil)
        return @component_root if name.nil?

        @component_root = name
      end

      def property_root(name = nil)
        return @property_root if name.nil?

        @property_root = name
      end

      def element_type
        @element_type
      end

      def type(element_type = nil)
        return @element_type if element_type.nil?

        unless ElementType::ALL.include?(element_type)
          raise ArgumentError, "Invalid element type: #{element_type}"
        end

        @element_type = element_type
      end

      def field_set
        @field_set
      end

      def field_set?
        !@field_set.nil?
      end

      def map_value(to:, **options)
        add_mapping(:value, to, vformat_type: :simple, **options)
      end

      def map_property(name, to:, type: :simple, **options)
        add_mapping(name.downcase, to, vformat_type: type, **options)
      end

      def map_component(name, to:, **options)
        add_mapping(name.downcase, to, vformat_type: :component, **options)
      end

      def map_field_set(count:, item_type:, item_options: {})
        @field_set = {
          count: count,
          item_type: item_type,
          options: item_options,
        }
      end

      def map_field(index, to:, **options)
        raise "map_field requires a preceding map_field_set" unless @field_set

        @mappings << FieldMappingRule.new(
          index,
          to: to,
          vformat_type: @field_set[:item_type],
          options: @field_set[:options].merge(options),
        )
      end

      # The wire name a property mapping serializes under.
      def wire_name_for(rule)
        rule.is_a?(FieldMappingRule) ? nil : rule.name.to_s.upcase
      end

      def root_name
        case @element_type
        when :component then @component_root
        when :property then @property_root
        end
      end

      private

      def add_mapping(name, to, **options)
        @mappings << MappingRule.new(
          name,
          to: to,
          **options,
        )
      end
    end
  end
end
