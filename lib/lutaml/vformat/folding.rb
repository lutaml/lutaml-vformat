# frozen_string_literal: true

module Lutaml
  module Vformat
    # Line folding (RFC 6350 section 3.2, RFC 5545 section 3.1).
    #
    # The limit counts octets of the encoded line, not characters, and a fold
    # never falls inside a multi-byte UTF-8 sequence. A continuation line
    # starts with one space that counts toward its limit.
    module Folding
      LIMIT = 75
      CRLF = "\r\n"

      module_function

      def fold(line, limit: LIMIT, eol: CRLF)
        bytes = line.b
        return line.dup if bytes.bytesize <= limit

        chunks(bytes, limit).join("#{eol} ".b).force_encoding(line.encoding)
      end

      # The first chunk gets +limit+ octets; later ones one fewer, because
      # each is written after a leading space.
      def chunks(bytes, limit)
        chunks = []
        pos = 0
        while pos < bytes.bytesize
          cut = cut_point(bytes, pos, pos.zero? ? limit : limit - 1)
          chunks << bytes.byteslice(pos, cut - pos)
          pos = cut
        end
        chunks
      end

      def unfold(text)
        text.gsub(/\r?\n[ \t]/, "")
      end

      # Largest end offset, at most +budget+ bytes after +pos+, that is not
      # in the middle of a UTF-8 sequence.
      def cut_point(bytes, pos, budget)
        cut = pos + budget
        return bytes.bytesize if cut >= bytes.bytesize

        cut -= 1 while cut > pos && continuation?(bytes.getbyte(cut))
        cut
      end

      def continuation?(byte)
        (byte & 0xC0) == 0x80
      end
    end
  end
end
