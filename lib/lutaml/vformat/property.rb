# frozen_string_literal: true

module Lutaml
  module Vformat
    # One content line: [group.]NAME[;PARAM=v1,v2]...:value
    #
    # +value+ is the raw wire text (still escaped); use #text or #fields for
    # the unescaped views. Names and parameter names are case-insensitive and
    # kept upper-case.
    class Property
      attr_reader :name, :group, :params, :value

      def initialize(name, value = "", params: {}, group: nil)
        @name = name.to_s.upcase
        @group = group
        @params = params.each_with_object({}) do |(k, v), h|
          h[k.to_s.upcase] = Array(v).map(&:to_s)
        end
        @value = value.to_s
      end

      def param(name)
        params[name.to_s.upcase]&.first
      end

      def param_values(name)
        params[name.to_s.upcase] || []
      end

      # The VALUE parameter, lower-cased, or nil.
      def value_type
        param("VALUE")&.downcase
      end

      def text
        Escaping.unescape(value)
      end

      def fields
        Structured.split(value)
      end

      def ==(other)
        other.is_a?(Property) && [name, group, params, value] ==
          [other.name, other.group, other.params, other.value]
      end
    end
  end
end
