# frozen_string_literal: true

module Lutaml
  module Vformat
    # Attribute and mapping lookups shared by ModelReader and ModelWriter.
    module ModelSupport
      private

      def attrs_of(klass)
        klass.attributes(@register)
      end

      def type_of(attribute)
        attribute.type(@register)
      end

      def property_model?(type)
        type.is_a?(Class) && type <= Lutaml::Model::Serialize &&
          type.mappings_for(:vobject)&.element_type == :property
      end

      # Array() would splat Struct-based values such as
      # DateAndOrTime::Instant.
      def list_of(value)
        return [] if value.nil?

        value.is_a?(::Array) ? value : [value]
      end
    end
  end
end
