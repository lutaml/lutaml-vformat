# frozen_string_literal: true

module Lutaml
  module Vformat
    # Text value escaping (RFC 6350 section 3.4): backslash, semicolon and
    # comma get a backslash prefix; a line break becomes the two characters
    # backslash-n.
    module Escaping
      BACKSLASH = "\\"
      ESCAPES = {
        BACKSLASH => BACKSLASH * 2,
        ";" => "#{BACKSLASH};",
        "," => "#{BACKSLASH},",
        "\n" => "#{BACKSLASH}n",
      }.freeze
      ESCAPABLE = Regexp.union(ESCAPES.keys)
      ESCAPE_SEQUENCE = /#{Regexp.escape(BACKSLASH)}(.)/m
      UNESCAPES = { "n" => "\n", "N" => "\n" }.freeze

      module_function

      def escape(text)
        text.to_s.gsub(/\r\n|\r|\n/, "\n").gsub(ESCAPABLE, ESCAPES)
      end

      # Unknown escapes drop the backslash; a trailing lone backslash is
      # kept literally.
      def unescape(text)
        text.gsub(ESCAPE_SEQUENCE) do
          char = Regexp.last_match(1)
          UNESCAPES.fetch(char, char)
        end
      end
    end
  end
end
