# frozen_string_literal: true

RSpec.describe Lutaml::Vformat::Writer do
  it "writes BEGIN/END with CRLF line endings and a final CRLF" do
    component = new_component("VCARD", properties: [new_property("FN", "Jo")])
    expect(write_vobject(component))
      .to eq("BEGIN:VCARD\r\nFN:Jo\r\nEND:VCARD\r\n")
  end

  it "writes properties before nested components" do
    outer = new_component("VEVENT",
                          properties: [new_property("UID", "1")],
                          components: [new_component("VALARM")])
    expect(write_vobject(outer)).to eq(
      "BEGIN:VEVENT\r\nUID:1\r\nBEGIN:VALARM\r\nEND:VALARM\r\nEND:VEVENT\r\n",
    )
  end

  it "writes the group prefix" do
    property = new_property("TEL", "x", group: "item1")
    expect(line_for(property)).to eq("item1.TEL:x")
  end

  describe "parameters" do
    it "joins multiple values with commas" do
      property = new_property("TEL", "x", params: { "type" => %w[work voice] })
      expect(line_for(property)).to eq("TEL;TYPE=work,voice:x")
    end

    it "quotes a value containing a colon" do
      property = new_property("X", "v", params: { "A" => ["a:b"] })
      expect(line_for(property)).to eq('X;A="a:b":v')
    end

    it "quotes a value containing a semicolon" do
      property = new_property("X", "v", params: { "A" => ["a;b"] })
      expect(line_for(property)).to eq('X;A="a;b":v')
    end

    it "quotes a value containing a comma, keeping the list apart" do
      property = new_property("X", "v", params: { "A" => ["a,b", "c"] })
      expect(line_for(property)).to eq('X;A="a,b",c:v')
    end

    it "does not quote a value with a space" do
      property = new_property("X", "v", params: { "A" => ["a b"] })
      expect(line_for(property)).to eq("X;A=a b:v")
    end

    it "refuses a value containing a double quote" do
      property = new_property("X", "v", params: { "A" => ['a"b'] })
      expect { line_for(property) }
        .to raise_error(Lutaml::Vformat::SerializeError, /double quote/)
    end
  end

  describe "folding" do
    it "folds every line at 75 octets" do
      lines = lines_for(new_property("NOTE", "x" * 300))
      expect(lines.map(&:bytesize)).to all(be <= 75)
    end

    it "folds a line of exactly 76 octets as 75 + 1" do
      lines = lines_for(new_property("NOTE", "x" * 71)) # "NOTE:" + 71 = 76
      expect(lines[1].bytesize).to eq(75)
      expect(lines[2]).to eq(" x")
    end

    it "does not fold a line of exactly 75 octets" do
      lines = lines_for(new_property("NOTE", "x" * 70))
      expect(lines).to eq(["BEGIN:A", "NOTE:#{'x' * 70}", "END:A"])
    end
  end

  it "survives a write/parse round trip" do
    property = new_property("NOTE", "é" * 90,
                            params: { "CN" => ["a:b"] }, group: "g")
    component = new_component("A", properties: [property],
                                   components: [new_component("B")])
    expect(parse_vobject(write_vobject(component))).to eq([component])
  end
end
