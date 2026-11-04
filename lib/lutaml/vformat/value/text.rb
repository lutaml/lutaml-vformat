# frozen_string_literal: true

module Lutaml
  module Vformat
    module Value
      class Text < Base
        def self.escaped?
          true
        end

        def self.native?(value)
          value.is_a?(::String)
        end

        def self.parse(wire)
          Escaping.unescape(wire)
        end

        def self.format(value)
          Escaping.escape(value)
        end
      end

      # RFC 3986 URI. Not text-escaped.
      class Uri < Base
        def self.native?(value)
          value.is_a?(::String)
        end

        def self.parse(wire)
          URI.parse(wire)
          raise URI::InvalidURIError, wire if wire.empty?

          wire
        rescue URI::InvalidURIError
          invalid!("URI", wire)
        end

        def self.format(value)
          parse(value.to_s)
        end
      end

      # RFC 5646 language tag.
      class LanguageTag < Base
        GRANDFATHERED = %w[
          en-GB-oed i-ami i-bnn i-default i-enochian i-hak i-klingon i-lux
          i-mingo i-navajo i-pwn i-tao i-tay i-tsu sgn-BE-FR sgn-BE-NL
          sgn-CH-DE
        ].map(&:downcase).freeze
        ALNUM = "[a-z0-9]"
        LANGTAG = /\A
          (?:[a-z]{2,3}(?:-[a-z]{3}){0,3}|[a-z]{4}|[a-z]{5,8})
          (?:-[a-z]{4})?
          (?:-(?:[a-z]{2}|\d{3}))?
          (?:-(?:#{ALNUM}{5,8}|\d#{ALNUM}{3}))*
          (?:-[0-9a-wy-z](?:-#{ALNUM}{2,8})+)*
          (?:-x(?:-#{ALNUM}{1,8})+)?
        \z/xi
        PRIVATE_USE = /\Ax(?:-#{ALNUM}{1,8})+\z/i

        def self.native?(value)
          value.is_a?(::String) && valid?(value)
        end

        def self.parse(wire)
          return wire if wire.match?(LANGTAG) || wire.match?(PRIVATE_USE) ||
            GRANDFATHERED.include?(wire.downcase)

          invalid!("language-tag", wire)
        end

        def self.format(value)
          parse(value.to_s)
        end
      end

      # Base64 (RFC 4648 section 4), strict. The native value is a Blob: a
      # plain binary String would be re-labelled as UTF-8 by lutaml-model's
      # attribute casting, which would make it unreadable as raw bytes.
      class Binary < Base
        # Immutable holder of raw bytes.
        class Blob
          attr_reader :bytes

          def initialize(bytes)
            @bytes = bytes.b.freeze
            freeze
          end

          def ==(other)
            other.is_a?(Blob) && bytes == other.bytes
          end
          alias eql? ==

          def hash
            bytes.hash
          end

          def to_s
            bytes
          end
        end

        def self.native?(value)
          value.is_a?(Blob)
        end

        def self.parse(wire)
          Blob.new(wire.unpack1("m0"))
        rescue ::ArgumentError
          invalid!("binary", wire)
        end

        def self.format(value)
          bytes = value.is_a?(Blob) ? value.bytes : value.to_s
          [bytes].pack("m0")
        end

        def self.serialize(value)
          value.nil? ? nil : format(value)
        end
      end
    end
  end
end
