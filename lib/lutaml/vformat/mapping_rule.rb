# frozen_string_literal: true

module Lutaml
  module Vformat
    # One mapping line. +kind+ is :property, :component, :value, :param,
    # :field or :group; +name+ is the vObject name (or field index).
    class MappingRule < Lutaml::Model::MappingRule
      KINDS = %i[property component value param field group].freeze

      attr_reader :kind, :value_type

      def initialize(name, to:, kind:, value_type: nil)
        super(name, to: to)
        @kind = kind
        @value_type = value_type
      end

      def deep_dup
        self.class.new(name.dup, to: to, kind: kind, value_type: value_type)
      end
    end
  end
end
