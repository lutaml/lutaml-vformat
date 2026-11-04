# frozen_string_literal: true

RSpec.describe Lutaml::Vformat::Value do
  let(:value_error) { raise_error(Lutaml::Vformat::ValueError) }

  describe ".for" do
    it "finds types by symbol, name and RFC 6350 spelling" do
      expect(described_class.for(:integer)).to eq(described_class::Integer)
      expect(described_class.for("UTC-OFFSET"))
        .to eq(described_class::UtcOffset)
      expect(described_class.for("language-tag"))
        .to eq(described_class::LanguageTag)
      expect(described_class.for("date-time"))
        .to eq(described_class::DateAndOrTime)
    end

    it "rejects an unknown type" do
      expect do
        described_class.for("nope")
      end.to raise_error(ArgumentError, /nope/)
    end
  end

  describe described_class::Text do
    it "parses by unescaping" do
      expect(described_class.parse("a\\nb\\,c")).to eq("a\nb,c")
    end

    it "serializes by escaping" do
      expect(described_class.format("a\nb,c;d")).to eq("a\\nb\\,c#{'\\'};d")
    end
  end

  describe described_class::Uri do
    it "parses a URI unchanged, without text unescaping" do
      expect(described_class.parse("https://example.com/a,b;c")).to eq("https://example.com/a,b;c")
    end

    it "accepts schemes without an authority" do
      expect(described_class.parse("tel:+1-555-0100")).to eq("tel:+1-555-0100")
      mail = "mailto:jo@example.com"
      expect(described_class.parse(mail)).to eq(mail)
    end

    it "serializes unchanged" do
      expect(described_class.format("urn:uuid:1234")).to eq("urn:uuid:1234")
    end

    it "rejects a malformed URI" do
      expect { described_class.parse("http://exa mple.com") }.to value_error
    end

    it "rejects an empty value" do
      expect { described_class.parse("") }.to value_error
    end
  end

  describe described_class::Binary do
    it "parses base64 to a binary string" do
      value = described_class.parse("AAEC/w==")
      expect(value.bytes).to eq("\x00\x01\x02\xFF".b)
      expect(value.bytes.encoding).to eq(Encoding::BINARY)
    end

    it "serializes without line breaks" do
      blob = described_class::Blob.new("\x00\x01\x02\xFF")
      expect(described_class.format(blob)).to eq("AAEC/w==")
      long = described_class::Blob.new("x" * 200)
      expect(described_class.format(long)).not_to include("\n")
    end

    it "round-trips" do
      bytes = (0..255).map(&:chr).join.b
      blob = described_class::Blob.new(bytes)
      expect(described_class.parse(described_class.format(blob))).to eq(blob)
    end

    it "rejects malformed base64" do
      expect { described_class.parse("not base64!") }.to value_error
      expect { described_class.parse("AAEC/w=") }.to value_error
    end
  end

  describe described_class::Boolean do
    it "parses TRUE and FALSE case-insensitively" do
      expect(described_class.parse("TRUE")).to be(true)
      expect(described_class.parse("false")).to be(false)
    end

    it "serializes to upper case" do
      expect(described_class.format(true)).to eq("TRUE")
      expect(described_class.format(false)).to eq("FALSE")
    end

    it "rejects anything else" do
      %w[yes 1 T].each do |v|
        expect do
          described_class.parse(v)
        end.to value_error
      end
    end
  end

  describe described_class::Integer do
    it "parses signed integers" do
      expect(described_class.parse("42")).to eq(42)
      expect(described_class.parse("-7")).to eq(-7)
      expect(described_class.parse("+7")).to eq(7)
    end

    it "serializes" do
      expect(described_class.format(-12)).to eq("-12")
    end

    it "rejects decimals, blanks and text" do
      ["1.5", "", "12a", " 1"].each do |v|
        expect do
          described_class.parse(v)
        end.to value_error
      end
    end
  end

  describe described_class::Float do
    it "parses decimals and integers" do
      expect(described_class.parse("1.25")).to eq(1.25)
      expect(described_class.parse("-3")).to eq(-3.0)
    end

    it "serializes in plain notation" do
      expect(described_class.format(1.5)).to eq("1.5")
      expect(described_class.format(0.00001)).to match(/\A0\.00001\z/)
      expect(described_class.format(1e20)).not_to include("e")
    end

    it "round-trips" do
      expect(described_class.parse(described_class.format(0.1))).to eq(0.1)
    end

    it "refuses non-finite numbers" do
      expect { described_class.format(Float::NAN) }.to raise_error(Lutaml::Vformat::SerializeError)
    end

    it "rejects exponent form and text" do
      %w[1e3 abc .].each do |v|
        expect do
          described_class.parse(v)
        end.to value_error
      end
    end
  end

  describe described_class::UtcOffset do
    it "parses to signed seconds" do
      expect(described_class.parse("+0530")).to eq(19_800)
      expect(described_class.parse("-0800")).to eq(-28_800)
      expect(described_class.parse("+053015")).to eq(19_815)
    end

    it "serializes" do
      expect(described_class.format(19_800)).to eq("+0530")
      expect(described_class.format(-28_800)).to eq("-0800")
      expect(described_class.format(0)).to eq("+0000")
      expect(described_class.format(19_815)).to eq("+053015")
    end

    it "rejects missing sign, bad shape and out-of-range parts" do
      %w[0530 +05 +5:30 +2500 +0560 Z].each do |v|
        expect { described_class.parse(v) }.to value_error
      end
    end
  end

  describe described_class::LanguageTag do
    %w[en en-US zh-Hant-TW sl-rozaj-biske de-CH-1901 es-419 x-private
       en-a-bbb-x-a-ccc i-klingon].each do |tag|
      it "accepts #{tag}" do
        expect(described_class.parse(tag)).to eq(tag)
      end
    end

    ["", "e", "en_US", "en-", "123", "en-US-", "toolonglanguage"].each do |tag|
      it "rejects #{tag.inspect}" do
        expect { described_class.parse(tag) }.to value_error
      end
    end

    it "serializes a valid tag unchanged" do
      expect(described_class.format("fr-CA")).to eq("fr-CA")
    end
  end

  describe described_class::DateAndOrTime do
    {
      "19850412" => :date, "1985-04-12" => :date, "1985" => :date,
      "1985-04" => :date, "--0412" => :date, "--04" => :date, "---12" => :date,
      "19961022T140000" => :date_time, "19961022T140000Z" => :date_time,
      "19961022T140000-0500" => :date_time,
      "1996-10-22T14:00:00Z" => :date_time,
      "--1022T1400" => :date_time, "---22T14" => :date_time,
      "T102200" => :time, "T1022" => :time, "T10" => :time, "T-22" => :time,
      "T--00" => :time, "T102200Z" => :time, "T102200+0800" => :time
    }.each do |text, kind|
      it "classifies #{text} as #{kind}" do
        value = described_class.parse(text)
        expect([value.kind, value.to_s]).to eq([kind, text])
      end

      it "serializes #{text} back unchanged" do
        expect(described_class.format(described_class.parse(text))).to eq(text)
      end
    end

    ["Early April 1985", "19851301", "19850432", "19961022T250000", "1985-4-12",
     "T", "", "19961022 140000"].each do |text|
      it "rejects #{text.inspect}" do
        expect { described_class.parse(text) }.to value_error
      end
    end

    it "compares by text" do
      first = described_class.parse("19850412")
      expect(first).to eq(described_class.parse("19850412"))
    end

    it "casts from a string when used as an attribute type" do
      expect(described_class.cast("19850412").kind).to eq(:date)
    end
  end
end
