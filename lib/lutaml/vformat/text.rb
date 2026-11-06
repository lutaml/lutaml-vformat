# frozen_string_literal: true

module Lutaml
  module Vformat
    # RFC 6350 §3.4 text escaping and the content-line folding rules.
    #
    # Escaping (property and parameter VALUES): backslash, semicolon,
    # and comma carry a preceding backslash; a literal newline (and a
    # CRLF pair) is the two-character sequence backslash + n.
    # Unescaping reverses both in one pass.
    #
    # Folding (§3.2): content lines longer than 75 octets fold, each
    # continuation line opening with a single space. The prefix is
    # inserted, never consuming content: unfolding strips exactly one
    # leading space per continuation, so the round trip is lossless
    # regardless of where the break falls. Breaks never split a
    # multi-byte character. Parsing first unfolds, so the parser never
    # sees folded input.
    module Text
      LINE_OCTETS = 75
      CONTINUATION_PREFIX = " "

      ESCAPES = {
        "\\" => "\\\\",
        "\r\n" => "\\n",
        ";" => "\\;",
        "," => "\\,",
        "\n" => "\\n",
        "\r" => "",
      }.freeze

      module_function

      def escape(value)
        value.to_s.gsub(/\\|\r\n|\r|\n|;|,/, ESCAPES)
      end

      # Single-pass unescape, longest-match first: a doubled backslash
      # followed by n/N is a literal backslash and the letter — not a
      # newline escape.
      def unescape(value)
        value.to_s.gsub(/\\\\[nN]|\\[nN;,\\]/) do |m|
          if m.length == 3
            "\\#{m[2]}"
          else
            case m[1]
            when "n", "N" then "\n"
            when ";" then ";"
            when "," then ","
            else "\\"
            end
          end
        end
      end

      # Unfold folded content lines: a line beginning with a space
      # continues the previous line (the leading space is not part of
      # the content).
      def unfold(lines)
        lines.each_with_object([]) do |line, unfolded|
          if line.start_with?(CONTINUATION_PREFIX) && !unfolded.empty?
            unfolded.last << line[1..]
          else
            unfolded << line
          end
        end
      end

      # Fold one content line into physical lines of at most
      # LINE_OCTETS octets, continuations prefixed with one space —
      # continuation chunks carry 74 content octets so the physical
      # line stays within the limit.
      def fold(line)
        return [line] if line.bytesize <= LINE_OCTETS

        out = []
        rest = line.to_s
        limit = LINE_OCTETS
        until rest.empty?
          chunk = take_octets(rest, limit)
          rest = rest[chunk.length..]
          out << chunk
          limit = LINE_OCTETS - 1
        end
        out.each_with_index.map { |l, i| i.zero? ? l : CONTINUATION_PREFIX + l }
      end

      # Take at most +count+ octets without splitting a character.
      def take_octets(string, count)
        return string if string.bytesize <= count

        cut = count
        cut -= 1 while cut.positive? && !string.byteslice(0,
                                                          cut).valid_encoding?
        string.byteslice(0, cut)
      end
    end
  end
end
