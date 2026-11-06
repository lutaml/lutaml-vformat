# frozen_string_literal: true

module Lutaml
  module Vformat
    # A property/value mapping row. `structure` carries the declared
    # structured-ness (`:structured` for semicolon-field properties);
    # `type` carries the row kind from the DSL (simple/component/
    # structured/list).
    class MappingRule < Lutaml::Model::MappingRule
      attr_reader :vformat_type, :structure, :options

      def initialize(name, to:, vformat_type: :simple, structure: nil,
                     options: {})
        super(name, to: to)
        @vformat_type = vformat_type
        @structure = structure
        @options = options
      end

      def structured?
        @vformat_type == :structured
      end

      def component?
        @vformat_type == :component
      end

      def deep_dup
        self.class.new(
          name.dup,
          to: to.dup,
          vformat_type: vformat_type,
          structure: structure&.dup,
          options: options.dup,
        )
      end
    end

    # A field row inside a map_field_set block: `name` is the field
    # INDEX (an Integer), the position in the semicolon-joined value.
    class FieldMappingRule < MappingRule; end
  end
end
