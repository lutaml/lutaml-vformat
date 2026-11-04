# frozen_string_literal: true

RSpec.describe Lutaml::Vformat::Parser do
  describe "components" do
    it "reads a flat component" do
      root = parse_vobject("BEGIN:VCARD\r\nFN:Jo\r\nEND:VCARD\r\n").first
      expect(root.name).to eq("VCARD")
      expect(root.property("FN").value).to eq("Jo")
    end

    it "nests components to any depth, in document order" do
      text = <<~VOBJECT
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:1
        BEGIN:VALARM
        ACTION:DISPLAY
        END:VALARM
        BEGIN:VALARM
        ACTION:AUDIO
        END:VALARM
        END:VEVENT
        BEGIN:VEVENT
        UID:2
        END:VEVENT
        END:VCALENDAR
      VOBJECT
      calendar = parse_vobject(text).first
      events = calendar.components_named("VEVENT")
      expect(events.map { |e| e.property("UID").value }).to eq(%w[1 2])
      alarms = events.first.components_named("VALARM")
      expect(alarms.map do |a|
        a.property("ACTION").value
      end).to eq(%w[DISPLAY AUDIO])
    end

    it "returns several top-level components" do
      text = "BEGIN:A\nX:1\nEND:A\nBEGIN:B\nX:2\nEND:B\n"
      expect(parse_vobject(text).map(&:name)).to eq(%w[A B])
    end

    it "is case-insensitive on names and keeps them upper-case" do
      root = parse_vobject("begin:vcard\nfn:Jo\nend:vcard\n").first
      expect(root.name).to eq("VCARD")
      expect(root.property("FN").value).to eq("Jo")
    end

    it "ignores blank lines" do
      root = parse_vobject("\nBEGIN:A\n\nX:1\n\nEND:A\n\n").first
      expect(root.property("X").value).to eq("1")
    end

    it "accepts LF and CRLF line endings" do
      crlf = parse_vobject("BEGIN:A\r\nX:1\r\nEND:A\r\n")
      expect(crlf).to eq(parse_vobject("BEGIN:A\nX:1\nEND:A\n"))
    end

    it "accepts CR CR LF line endings, leaving no CR in values" do
      text = "BEGIN:A\r\r\nX:ab\r\r\n c\r\r\nEND:A\r\r\n"
      expected = parse_vobject("BEGIN:A\nX:abc\nEND:A\n")
      expect(parse_vobject(text)).to eq(expected)
    end

    it "ignores a leading byte order mark" do
      expect(parse_vobject("﻿BEGIN:A\nEND:A\n").first.name).to eq("A")
    end
  end

  describe "malformed input" do
    {
      "a mismatched END" => "BEGIN:A\nEND:B\n",
      "an END with no BEGIN" => "END:A\n",
      "an unterminated component" => "BEGIN:A\nX:1\n",
      "a property outside a component" => "X:1\nBEGIN:A\nEND:A\n",
      "a line without a colon" => "BEGIN:A\nNOCOLON\nEND:A\n",
      "an invalid name" => "BEGIN:A\n=bad:1\nEND:A\n",
    }.each do |name, text|
      it "raises ParseError for #{name}" do
        expect { parse_vobject(text) }.to raise_error(Lutaml::Vformat::ParseError)
      end
    end

    it "raises ParseError for invalid UTF-8" do
      expect { parse_vobject("BEGIN:A\nX:\xFF\nEND:A\n".b) }
        .to raise_error(Lutaml::Vformat::ParseError, /UTF-8/)
    end

    it "names the offending line" do
      expect { parse_vobject("BEGIN:A\nX:1\nEND:B\n") }
        .to raise_error(Lutaml::Vformat::ParseError, /line 3/)
    end
  end

  describe "property parameters" do
    let(:property) do
      parse_vobject("BEGIN:A\n#{line}\nEND:A\n").first.properties.first
    end

    context "with a plain parameter" do
      let(:line) { "TEL;TYPE=work:+1 555" }

      it "reads name, parameter and value" do
        expect(property.name).to eq("TEL")
        expect(property.param("TYPE")).to eq("work")
        expect(property.value).to eq("+1 555")
      end
    end

    context "with a bare parameter (vCard 2.1 style)" do
      let(:line) { "TEL;WORK;VOICE:+1 555" }

      it "reads it as a TYPE value" do
        expect(property.params).to eq("TYPE" => %w[WORK VOICE])
      end
    end

    context "with a bare encoding parameter" do
      let(:line) { "PHOTO;BASE64:AAAA" }

      it "reads it as ENCODING" do
        expect(property.params).to eq("ENCODING" => ["BASE64"])
      end
    end

    context "with several parameters" do
      let(:line) { "TEL;TYPE=work;PREF=1:x" }

      it "reads all of them" do
        expect(property.params).to eq("TYPE" => ["work"], "PREF" => ["1"])
      end
    end

    context "with a comma-separated value list" do
      let(:line) { "TEL;TYPE=work,voice:x" }

      it "reads each value" do
        expect(property.param_values("TYPE")).to eq(%w[work voice])
      end
    end

    context "with a repeated parameter" do
      let(:line) { "TEL;TYPE=work;TYPE=voice:x" }

      it "collects the values in order" do
        expect(property.param_values("TYPE")).to eq(%w[work voice])
      end
    end

    context "with a quoted value containing a colon, semicolon and comma" do
      let(:line) { 'ATTENDEE;CN="Doe; Jo, Dr:":mailto:jo@example.com' }

      it "keeps the quoted text as one value" do
        expect(property.param("CN")).to eq("Doe; Jo, Dr:")
      end

      it "takes the value after the first unquoted colon" do
        expect(property.value).to eq("mailto:jo@example.com")
      end
    end

    context "with a quoted list mixing quoted and bare values" do
      let(:line) { 'X;TYPE="a,b",c:v' }

      it "does not split inside the quotes" do
        expect(property.param_values("TYPE")).to eq(["a,b", "c"])
      end
    end

    context "with a lower-case parameter name" do
      let(:line) { "TEL;type=work:x" }

      it "upper-cases the name and keeps the value" do
        expect(property.params).to eq("TYPE" => ["work"])
      end
    end

    context "with an empty parameter value" do
      let(:line) { "X;A=:v" }

      it "reads an empty string" do
        expect(property.param("A")).to eq("")
      end
    end

    context "with a group prefix" do
      let(:line) { "item1.TEL;TYPE=work:x" }

      it "separates group and name" do
        expect([property.group, property.name]).to eq(%w[item1 TEL])
      end
    end

    context "with colons in the value" do
      let(:line) { "URL:https://example.com:8080/a" }

      it "keeps everything after the first colon" do
        expect(property.value).to eq("https://example.com:8080/a")
      end
    end
  end

  describe "folded lines" do
    it "unfolds before reading" do
      text = "BEGIN:A\r\nNOTE:abc\r\n def\r\n\tghi\r\nEND:A\r\n"
      note = parse_vobject(text).first.property("NOTE")
      expect(note.value).to eq("abcdefghi")
    end

    it "does not break a multibyte character folded between its bytes" do
      line = Lutaml::Vformat::Folding.fold("NOTE:#{'é' * 80}")
      text = "BEGIN:A\r\n#{line}\r\nEND:A\r\n"
      expect(parse_vobject(text).first.property("NOTE").value).to eq("é" * 80)
    end
  end
end
