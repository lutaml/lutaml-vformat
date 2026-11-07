# frozen_string_literal: true

module Lutaml
  module Vformat
    # Wire text <-> attribute values. A vObject value type (or the
    # +value_type:+ of a mapping rule) wins; plain lutaml-model String,
    # Integer, Float and Boolean attributes use the matching vObject type;
    # anything else is cast from the unescaped text.
    module Codec
      BUILTIN = {
        Lutaml::Model::Type::String => Value::Text,
        Lutaml::Model::Type::Integer => Value::Integer,
        Lutaml::Model::Type::Float => Value::Float,
        Lutaml::Model::Type::Boolean => Value::Boolean,
      }.freeze

      module_function

      def value_class(type, value_type = nil)
        return Value.for(value_type) if value_type
        return type if type <= Value::Base

        BUILTIN[type]
      end

      def read(type, wire, value_type: nil)
        klass = value_class(type, value_type)
        return klass.parse(wire) if klass

        type.cast(Escaping.unescape(wire))
      end

      # Parameter values are never text-escaped.
      def read_param(type, text, value_type: nil)
        klass = value_class(type, value_type)
        return type.cast(text) if klass.nil?

        klass.escaped? ? text : klass.parse(text)
      end

      def write(type, value, value_type: nil)
        klass = value_class(type, value_type)
        return klass.format(value) if klass

        return Value::Boolean.format(value) if [true, false].include?(value)

        Escaping.escape(type.serialize(value).to_s)
      end

      def write_param(type, value, value_type: nil)
        klass = value_class(type, value_type)
        return value.to_s unless klass

        klass.escaped? ? value.to_s : klass.format(value)
      end
    end
  end
end
