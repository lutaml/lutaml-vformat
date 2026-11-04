# frozen_string_literal: true

module Lutaml
  module Vformat
    # The +vobject do ... end+ block.
    #
    #   vobject do
    #     type :component            # or :property
    #     component_root "VEVENT"    # type :component, top-level name
    #     property_root "TEL"        # type :property, informational
    #
    #     map_property "SUMMARY", to: :summary
    #     map_component "VALARM", to: :alarms
    #
    #     # in a property model:
    #     map_value to: :value
    #     map_param "TYPE", to: :types
    #     map_group to: :group
    #     map_field 0, to: :family   # structured value, ";"-separated
    #   end
    class Mapping < Lutaml::Model::Mapping
      TYPES = %i[component property].freeze

      attr_reader :mappings, :element_type, :component_name, :property_name

      def initialize
        super
        @element_type = nil
        @component_name = nil
        @property_name = nil
      end

      def deep_dup
        duped = super
        duped.copy_roots(@element_type, @component_name, @property_name)
        duped
      end

      def copy_roots(element_type, component_name, property_name)
        @element_type = element_type
        @component_name = component_name
        @property_name = property_name
      end

      def finalize(_mapper_class)
        @finalized = true
      end

      def finalized?
        @finalized == true
      end

      def type(element_type)
        unless TYPES.include?(element_type)
          raise ArgumentError,
                "Invalid element type: #{element_type.inspect} " \
                "(expected one of #{TYPES.inspect})"
        end

        @element_type = element_type
      end

      def component_root(name)
        @component_name = name.to_s.upcase
      end

      def property_root(name)
        @property_name = name.to_s.upcase
      end

      def map_property(name, to:, value_type: nil)
        add(name.to_s.upcase, to, :property, value_type)
      end

      def map_component(name, to:)
        add(name.to_s.upcase, to, :component, nil)
      end

      def map_value(to:, value_type: nil)
        add("VALUE", to, :value, value_type)
      end

      def map_param(name, to:, value_type: nil)
        add(name.to_s.upcase, to, :param, value_type)
      end

      def map_field(index, to:, value_type: nil)
        add(index, to, :field, value_type)
      end

      def map_group(to:)
        add("GROUP", to, :group, nil)
      end

      def rules(kind)
        @mappings.select { |r| r.kind == kind }
      end

      private

      def add(name, to, kind, value_type)
        @mappings << MappingRule.new(name, to: to, kind: kind,
                                           value_type: value_type)
      end
    end
  end
end
