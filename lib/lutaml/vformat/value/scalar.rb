# frozen_string_literal: true

module Lutaml
  module Vformat
    module Value
      class Boolean < Base
        def self.native?(value)
          [true, false].include?(value)
        end

        def self.parse(wire)
          case wire.upcase
          when "TRUE" then true
          when "FALSE" then false
          else invalid!("boolean", wire)
          end
        end

        def self.format(value)
          value ? "TRUE" : "FALSE"
        end
      end

      class Integer < Base
        def self.native?(value)
          value.is_a?(::Integer)
        end

        def self.parse(wire)
          invalid!("integer", wire) unless wire.match?(/\A[+-]?\d+\z/)

          wire.to_i
        end

        def self.format(value)
          Integer(value).to_s
        end
      end

      class Float < Base
        def self.native?(value)
          value.is_a?(::Float)
        end

        def self.parse(wire)
          invalid!("float", wire) unless wire.match?(/\A[+-]?\d+(\.\d+)?\z/)

          wire.to_f
        end

        # Plain decimal notation, never exponent form.
        def self.format(value)
          number = Kernel.Float(value)
          unless number.finite?
            raise SerializeError, "#{value} has no vObject float form"
          end

          text = number.to_s
          text.include?("e") ? expand(number) : text
        end

        def self.expand(number)
          ::Kernel.format("%.17f", number).sub(/0+\z/, "").sub(/\.\z/, ".0")
        end
        private_class_method :expand
      end

      # +hhmm or -hhmm, optionally with seconds. Native value: signed seconds
      # east of UTC.
      class UtcOffset < Base
        PATTERN = /\A([+-])(\d{2})(\d{2})(\d{2})?\z/

        def self.native?(value)
          value.is_a?(::Integer)
        end

        def self.parse(wire)
          match = PATTERN.match(wire) or invalid!("utc-offset", wire)
          hours, minutes, seconds = match.values_at(2, 3, 4).map(&:to_i)
          invalid!("utc-offset", wire) if out_of_range?(hours, minutes, seconds)

          total = (hours * 3600) + (minutes * 60) + seconds
          match[1] == "-" ? -total : total
        end

        def self.out_of_range?(hours, minutes, seconds)
          hours > 23 || minutes > 59 || seconds > 59
        end
        private_class_method :out_of_range?

        def self.format(value)
          seconds = Kernel.Integer(value)
          hours, rest = seconds.abs.divmod(3600)
          minutes, secs = rest.divmod(60)
          sign = seconds.negative? ? "-" : "+"
          text = ::Kernel.format("%<s>s%<h>02d%<m>02d", s: sign, h: hours,
                                                        m: minutes)
          secs.zero? ? text : text + ::Kernel.format("%02d", secs)
        end
      end
    end
  end
end
