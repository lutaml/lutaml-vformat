# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Vformat do
  describe "value types" do
    describe Lutaml::Vformat::VobjectValueType::Text do
      it "handles text values" do
        text = described_class.new("Sample text")
        expect(text.to_s).to eq("Sample text")
        expect(text).to be_valid
      end
    end

    describe Lutaml::Vformat::VobjectValueType::Uri do
      it "validates valid URIs" do
        expect(described_class.new("https://example.com")).to be_valid
      end

      it "invalidates malformed URIs" do
        expect(described_class.new("not-a-uri")).not_to be_valid
      end
    end

    describe Lutaml::Vformat::VobjectValueType::Binary do
      it "validates base64 encoded data" do
        expect(described_class.new("SGVsbG8gV29ybGQ=")).to be_valid
      end

      it "invalidates malformed base64 data" do
        expect(described_class.new("not-base64!")).not_to be_valid
      end
    end

    describe Lutaml::Vformat::VobjectValueType::Boolean do
      it "handles true values" do
        bool = described_class.new("TRUE")
        expect(bool).to be_valid
        expect(bool.to_bool).to be(true)
      end

      it "handles false values" do
        bool = described_class.new("false")
        expect(bool).to be_valid
        expect(bool.to_bool).to be(false)
      end

      it "invalidates non-boolean values" do
        expect(described_class.new("maybe")).not_to be_valid
      end
    end

    describe Lutaml::Vformat::VobjectValueType::Integer do
      it "validates integer values" do
        int = described_class.new("42")
        expect(int).to be_valid
        expect(int.to_i).to eq(42)
      end

      it "handles negative integers" do
        int = described_class.new("-42")
        expect(int).to be_valid
        expect(int.to_i).to eq(-42)
      end

      it "truncates floats to integers" do
        expect(described_class.new("4.2").to_i).to eq(4)
      end
    end

    describe Lutaml::Vformat::VobjectValueType::Float do
      it "validates float values" do
        number = described_class.new("4.2")
        expect(number).to be_valid
        expect(number.to_f).to eq(4.2)
      end

      it "handles negative floats" do
        expect(described_class.new("-4.2")).to be_valid
      end

      it "handles integer-like floats" do
        expect(described_class.new("42").to_f).to eq(42.0)
      end
    end

    describe Lutaml::Vformat::VobjectValueType::UtcOffset do
      it "validates UTC offset format" do
        offset = described_class.new("+0200")
        expect(offset).to be_valid
        expect(offset.hours).to eq(2)
        expect(offset.minutes).to be_zero
      end

      it "handles negative offsets" do
        offset = described_class.new("-0500")
        expect(offset).to be_valid
        expect(offset.hours).to eq(-5)
      end

      it "invalidates malformed offsets" do
        expect(described_class.new("0200")).not_to be_valid
      end
    end

    describe Lutaml::Vformat::VobjectValueType::Language do
      it "validates language tags" do
        expect(described_class.new("en-US")).to be_valid
      end

      it "validates simple language codes" do
        expect(described_class.new("en")).to be_valid
      end

      it "invalidates malformed tags" do
        expect(described_class.new("not-a-language!")).not_to be_valid
      end
    end

    describe Lutaml::Vformat::VobjectValueType::IsoDateAndOrTime do
      it "detects date-time forms" do
        expect(described_class.new("2024-01-15T10:30:00Z").type)
          .to eq(:date_time)
        expect(described_class.new("20240115T103000Z").type)
          .to eq(:date_time)
        expect(described_class.new("T103000").type).to eq(:date_time)
      end

      it "detects date forms" do
        expect(described_class.new("2024-01-15").type).to eq(:date)
        expect(described_class.new("20240115").type).to eq(:date)
        expect(described_class.new("--0105").type).to eq(:date)
      end

      it "falls back to text" do
        expect(described_class.new("birthday").type).to eq(:text)
      end
    end

    describe Lutaml::Vformat::VobjectPropertyValue do
      it "parses by VALUE parameter spelling" do
        value = described_class.parse("+0200", "UTC-OFFSET")
        expect(value).to be_a(Lutaml::Vformat::VobjectValueType::UtcOffset)
      end

      it "defaults to text" do
        expect(described_class.parse("anything"))
          .to be_a(Lutaml::Vformat::VobjectValueType::Text)
      end

      it "rejects unknown element types" do
        expect { described_class.parse("x", nil, :bogus) }
          .to raise_error(ArgumentError, /Invalid element type/)
      end
    end
  end

  describe "text escaping and folding" do
    it "escapes and unescapes the special characters" do
      escaped = Lutaml::Vformat::Text.escape("a;b,c\\d\ne")
      expect(escaped).to eq("a\\;b\\,c\\\\d\\ne")
      expect(Lutaml::Vformat::Text.unescape(escaped)).to eq("a;b,c\\d\ne")
    end

    it "escapes CRLF as the newline escape" do
      expect(Lutaml::Vformat::Text.escape("a\r\nb")).to eq("a\\nb")
    end

    it "folds long lines at 75 octets with a continuation space" do
      folded = Lutaml::Vformat::Text.fold("x" * 200)
      expect(folded.length).to be > 1
      expect(folded.first.bytesize).to be <= 75
      expect(folded[1..]).to all(start_with(" "))
      expect(Lutaml::Vformat::Text.unfold(folded).join).to eq("x" * 200)
    end

    it "never splits a multi-byte character" do
      folded = Lutaml::Vformat::Text.fold("日本語テキスト" * 30)
      expect(folded).to all(be_valid_encoding)
      expect(Lutaml::Vformat::Text.unfold(folded).join).to eq("日本語テキスト" * 30)
    end

    it "unfolds folded input transparently when parsing" do
      long_value = "word " * 30
      vcard = build_vcard(fn_value: long_value)
      source = vcard.to_vobject
      expect(source).to include("\n ")

      reparsed = VcardModel.from_vobject(source)
      expect(reparsed.fn).to eq(long_value)
    end
  end

  describe "property groups" do
    it "parses group-prefixed properties and preserves the group" do
      source = "BEGIN:VCARD\nitem1.TEL:+1-555\nitem2.TEL:+1-666\nEND:VCARD"
      document = Lutaml::Vformat::Document.parse(source)
      component = document[0]

      expect(component[:groups]["tel"]).to contain_exactly(
        { value: "+1-555", params: {}, group: "item1" },
        { value: "+1-666", params: {}, group: "item2" },
      )
    end

    it "splits quoted parameter values on semicolons and commas" do
      source = "BEGIN:VCARD\nTEL;TYPE=\"work,cell\";" \
               "X-A=\"a;b\":+1-555\nEND:VCARD"
      entry = Lutaml::Vformat::Document.parse(source)[0][:properties]["tel"].first
      expect(entry[:params]["TYPE"]).to eq("work,cell")
      expect(entry[:params]["X-A"]).to eq("a;b")
    end
  end

  describe "model round trips" do
    it "round-trips a vCard component" do
      source = <<~VOBJECT
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        N:Doe;John;;;
        TEL;TYPE=work:+1-555
        EMAIL:john@example.com
        BDAY:19900101
        END:VCARD
      VOBJECT

      vcard = VcardModel.from_vobject(source)
      expect(vcard.version).to eq("4.0")
      expect(vcard.fn).to eq("John Doe")
      expect(vcard.n.family).to eq("Doe")
      expect(vcard.n.given).to eq("John")
      expect(vcard.tel.map(&:value)).to eq(["+1-555"])
      expect(vcard.tel.first.type).to eq("work")
      expect(vcard.email).to eq(["john@example.com"])
      expect(vcard.bday.value.value).to eq("19900101")

      output = vcard.to_vobject
      restored = VcardModel.from_vobject(output)
      expect(restored.version).to eq(vcard.version)
      expect(restored.fn).to eq(vcard.fn)
      expect(restored.n.family).to eq(vcard.n.family)
      expect(restored.n.given).to eq(vcard.n.given)
      expect(restored.tel.map(&:value)).to eq(vcard.tel.map(&:value))
      expect(restored.tel.map(&:type)).to eq(vcard.tel.map(&:type))
      expect(restored.email).to eq(vcard.email)
      expect(restored.bday.value.value).to eq(vcard.bday.value.value)
    end

    it "serializes multiple TEL entries as separate content lines" do
      vcard = build_vcard(fn_value: "Jane", tel_list: %w[+1-1 +1-2])
      source = vcard.to_vobject
      expect(source.scan(/^TEL:/).length).to eq(2)
    end

    it "escapes special characters in property values on output" do
      vcard = build_vcard(fn_value: "Done; with, commas\\and\nnewlines")
      source = vcard.to_vobject
      expect(source).to include("FN:Done\\; with\\, commas\\\\and\\nnewlines")
      expect(VcardModel.from_vobject(source).fn)
        .to eq("Done; with, commas\\and\nnewlines")
    end

    it "folds serialized content lines over 75 octets" do
      vcard = build_vcard(fn_value: "F" * 300)
      source = vcard.to_vobject
      physical = source.split("\n")
      expect(physical.map(&:bytesize)).to all(be <= 75)
      expect(VcardModel.from_vobject(source).fn).to eq("F" * 300)
    end
  end
end
