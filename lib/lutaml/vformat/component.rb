# frozen_string_literal: true

module Lutaml
  module Vformat
    # A BEGIN:NAME ... END:NAME block holding properties and nested components,
    # each in document order.
    class Component
      attr_reader :name, :properties, :components

      def initialize(name, properties: [], components: [])
        @name = name.to_s.upcase
        @properties = properties
        @components = components
      end

      def properties_named(name)
        properties.select { |p| p.name == name.to_s.upcase }
      end

      def components_named(name)
        components.select { |c| c.name == name.to_s.upcase }
      end

      def property(name)
        properties_named(name).first
      end

      def ==(other)
        other.is_a?(Component) && [name, properties, components] ==
          [other.name, other.properties, other.components]
      end
    end
  end
end
