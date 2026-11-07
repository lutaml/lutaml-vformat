# frozen_string_literal: true

module Lutaml
  module Vformat
    # A parsed vObject stream: zero or more top-level components.
    class Document
      attr_reader :components

      def self.parse(data, _options = {})
        new(Parser.parse(data))
      end

      def initialize(components = [], _options = {})
        components = components.components if components.is_a?(Document)
        @components = Array(components)
      end

      def component(name)
        @components.find { |c| c.name == name.to_s.upcase }
      end

      def to_vobject(_options = {})
        Writer.write(@components)
      end

      def ==(other)
        other.is_a?(Document) && components == other.components
      end
    end
  end
end
