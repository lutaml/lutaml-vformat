# frozen_string_literal: true

module Lutaml
  module Vformat
    module Value
      # A vObject value type. Subclasses define .parse (wire text to a Ruby
      # object, raising ValueError) and .format (Ruby object to wire text).
      # They are also lutaml-model attribute types: assigning wire text or a
      # native object casts to the native object.
      class Base < Lutaml::Model::Type::Value
        # Whether wire text of this type is subject to text escaping.
        def self.escaped?
          false
        end

        def self.cast(value, _options = EMPTY_OPTIONS)
          return nil if value.nil?
          return value if Lutaml::Model::Utils.uninitialized?(value)

          native?(value) ? value : parse(value.to_s)
        end

        def self.valid?(wire)
          parse(wire)
          true
        rescue ValueError
          false
        end

        def self.from_vobject(wire)
          parse(wire)
        end

        def self.native?(_value)
          false
        end

        def self.invalid!(type_name, wire)
          raise ValueError, "#{wire.inspect} is not a valid #{type_name} value"
        end
        private_class_method :invalid!
      end
    end
  end
end
