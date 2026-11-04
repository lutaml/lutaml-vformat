# frozen_string_literal: true

require "strscan"

module Lutaml
  module Vformat
    # Text to Components. Unfolds first, then reads content lines.
    class Parser
      NAME = /[A-Za-z0-9-]+/
      BARE_ENCODINGS = %w[BASE64 QUOTED-PRINTABLE 8BIT 7BIT].freeze
      GROUP_AND_NAME = /(?:(?<group>#{NAME})\.)?(?<name>#{NAME})/
      PARAM_VALUE = /"[^"]*"|[^";:,]*/

      def self.parse(data)
        new(data).parse
      end

      def initialize(data)
        @text = normalize(data)
      end

      # @return [Array<Component>] the top-level components
      def parse
        roots = []
        stack = []
        lines.each { |line, number| handle(line, number, roots, stack) }
        unless stack.empty?
          raise ParseError,
                "missing END:#{stack.last.name} (unterminated component)"
        end

        roots
      end

      private

      # Non-blank unfolded lines with their 1-based number.
      def lines
        Folding.unfold(@text).split(/\r*\n/).each_with_index
          .reject { |line, _| line.strip.empty? }
          .map { |line, index| [line, index + 1] }
      end

      def normalize(data)
        text = data.to_s.dup.force_encoding(Encoding::UTF_8)
        text = text.delete_prefix("﻿")
        raise ParseError, "input is not valid UTF-8" unless text.valid_encoding?

        text
      end

      def handle(line, number, roots, stack)
        property = parse_line(line, number)
        case property.name
        when "BEGIN" then open_component(property, stack)
        when "END" then close_component(property, number, roots, stack)
        else add_property(property, number, stack)
        end
      end

      def open_component(property, stack)
        stack.push(Component.new(property.value.strip))
      end

      def close_component(property, number, roots, stack)
        name = property.value.strip.upcase
        current = stack.pop
        if current.nil? || current.name != name
          raise ParseError,
                "line #{number}: END:#{name} does not match " \
                "#{current ? "BEGIN:#{current.name}" : 'any open component'}"
        end

        (stack.last ? stack.last.components : roots) << current
      end

      def add_property(property, number, stack)
        if stack.empty?
          raise ParseError,
                "line #{number}: property outside a component"
        end

        stack.last.properties << property
      end

      def parse_line(line, number)
        scanner = StringScanner.new(line)
        unless scanner.scan(GROUP_AND_NAME)
          raise ParseError, "line #{number}: invalid property name"
        end

        group = scanner[:group]
        name = scanner[:name]
        params = scan_params(scanner, number)
        raise ParseError, "line #{number}: missing ':'" unless scanner.scan(":")

        Property.new(name, scanner.rest, params: params, group: group)
      end

      def scan_params(scanner, number)
        params = {}
        while scanner.scan(";")
          name, values = scan_param(scanner, number)
          (params[name] ||= []).concat(values)
        end
        params
      end

      def scan_param(scanner, number)
        unless scanner.scan(NAME)
          raise ParseError, "line #{number}: invalid parameter name"
        end

        name = scanner.matched.upcase
        return bare_param(name) unless scanner.scan("=")

        [name, scan_param_values(scanner)]
      end

      # vCard 2.1 style "TEL;WORK:" or "PHOTO;BASE64:". Address books still
      # write these in 3.0 cards, so read them as TYPE or ENCODING values.
      def bare_param(name)
        BARE_ENCODINGS.include?(name) ? ["ENCODING", [name]] : ["TYPE", [name]]
      end

      def scan_param_values(scanner)
        values = []
        loop do
          scanner.scan(PARAM_VALUE)
          values << scanner.matched.delete_prefix('"').delete_suffix('"')
          break unless scanner.scan(",")
        end
        values
      end
    end
  end
end
