# frozen_string_literal: true

module Lutaml
  module Vformat
    # The four element kinds a mapping may declare.
    module ElementType
      COMPONENT = :component
      PROPERTY = :property
      PROPERTY_PARAMETER = :property_parameter
      PROPERTY_GROUP = :property_group

      ALL = [COMPONENT, PROPERTY, PROPERTY_PARAMETER,
             PROPERTY_GROUP].freeze
    end

    # Whether a value sits in the property-value or parameter-value
    # position.
    module ValueType
      PROPERTY_VALUE = :property_value
      PARAMETER_VALUE = :parameter_value
    end
  end
end
