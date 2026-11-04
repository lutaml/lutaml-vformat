# frozen_string_literal: true

RSpec.describe Lutaml::Vformat::Escaping do
  describe ".escape" do
    {
      "backslash" => ["a\\b", "a\\\\b"],
      "comma" => ["a,b", "a\\,b"],
      "semicolon" => ["a;b", "a\\;b"],
      "newline" => ["a\nb", "a\\nb"],
      "CRLF" => ["a\r\nb", "a\\nb"],
      "lone CR" => ["a\rb", "a\\nb"],
    }.each do |name, (plain, wire)|
      it "escapes #{name}" do
        expect(described_class.escape(plain)).to eq(wire)
      end
    end

    it "escapes the backslash before the characters it introduces" do
      expect(described_class.escape("\\,")).to eq("\\\\\\,")
    end

    it "leaves colons, quotes and non-ASCII alone" do
      expect(described_class.escape("a:\"é")).to eq("a:\"é")
    end

    it "accepts nil as empty" do
      expect(described_class.escape(nil)).to eq("")
    end
  end

  describe ".unescape" do
    let(:bs) { "\\" }

    it "reverses every escape" do
      wire = "a#{bs}#{bs}b#{bs},c#{bs};d#{bs}ne"
      expect(described_class.unescape(wire)).to eq("a#{bs}b,c;d\ne")
    end

    it "accepts an upper-case \\N" do
      expect(described_class.unescape("a\\Nb")).to eq("a\nb")
    end

    it "drops the backslash of an unknown escape" do
      expect(described_class.unescape("a\\qb")).to eq("aqb")
    end

    it "keeps a trailing lone backslash" do
      expect(described_class.unescape("ab\\")).to eq("ab\\")
    end

    it "does not treat an escaped backslash followed by n as a newline" do
      expect(described_class.unescape("a\\\\nb")).to eq("a\\nb")
    end
  end

  it "round-trips text containing every special character" do
    text = "x\\y,z;w\nv\\n\\,"
    expect(described_class.unescape(described_class.escape(text))).to eq(text)
  end
end
