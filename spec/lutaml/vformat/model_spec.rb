# frozen_string_literal: true

RSpec.describe "vObject model round trip" do
  let(:card_class) { VformatSpecModels::Card }
  let(:calendar_class) { VformatSpecModels::Calendar }

  let(:card_text) do
    [
      "BEGIN:VCARD",
      "FN:Jo Doe",
      "N:Doe;Jo;Q,R",
      "TEL;TYPE=\"work,home\",cell;PREF=1:+1 555 0100",
      "item1.TEL:+1 555 0101",
      "NOTE:one\\, two\\; three\\nfour",
      "X-VERIFIED:TRUE",
      "X-SCORE:2.5",
      "PHOTO:AAEC/w==",
      "TZ:+0530",
      "LANG:en-US",
      "BDAY:19850412",
      "END:VCARD",
      "",
    ].join("\r\n")
  end

  describe "parsing" do
    subject(:card) { card_class.from_vobject(card_text) }

    it "reads text, escaping included" do
      expect(card.fn).to eq("Jo Doe")
      expect(card.note).to eq("one, two; three\nfour")
    end

    it "reads a structured value into fields, with a multi-valued field" do
      expect(card.n.family).to eq("Doe")
      expect(card.n.given).to eq("Jo")
      expect(card.n.additional).to eq(%w[Q R])
    end

    it "reads parameters, including a quoted list and a repeated property" do
      expect(card.tel.map(&:number)).to eq(["+1 555 0100", "+1 555 0101"])
      expect(card.tel.first.types).to eq(%w[work,home cell])
      expect(card.tel.first.pref).to eq(1)
      expect(card.tel.last.group).to eq("item1")
      expect(card.tel.last.pref).to be_nil
    end

    it "reads every value type into its native object" do
      expect(card.verified).to be(true)
      expect(card.score).to eq(2.5)
      expect(card.photo.bytes).to eq("\x00\x01\x02\xFF".b)
      expect(card.tz).to eq(19_800)
      expect(card.lang).to eq("en-US")
      expect(card.bday.kind).to eq(:date)
      expect(card.bday.to_s).to eq("19850412")
    end

    it "treats an absent structured field as nil" do
      parsed = card_class.from_vobject("BEGIN:VCARD\nN:Doe;;\nEND:VCARD\n")
      expect(parsed.n.family).to eq("Doe")
      expect(parsed.n.given).to be_nil
    end

    it "unfolds long lines, multibyte characters included" do
      note = "日本語" * 60
      folded = Lutaml::Vformat::Folding.fold("NOTE:#{note}")
      text = "BEGIN:VCARD\r\n#{folded}\r\nEND:VCARD\r\n"
      parsed = card_class.from_vobject(text)
      expect(parsed.note).to eq(note)
    end
  end

  describe "serializing" do
    subject(:written) { card_class.from_vobject(card_text).to_vobject }

    it "reproduces the canonical text exactly" do
      expect(written).to eq(card_text)
    end

    it "uses CRLF and ends with a line break" do
      expect(written).to end_with("END:VCARD\r\n")
      expect(written.gsub("\r\n", "")).not_to include("\n")
    end

    it "folds at 75 octets, multibyte text included, and unfolds back" do
      card = card_class.new(fn: "x", note: "é;" * 200)
      text = card.to_vobject
      expect(text.split("\r\n").map(&:bytesize)).to all(be <= 75)
      expect(text.split("\r\n").map(&:valid_encoding?)).to all(be(true))
      expect(card_class.from_vobject(text).note).to eq(card.note)
    end

    it "escapes backslash, comma, semicolon and newline in text" do
      text = card_class.new(note: "a\\b,c;d\ne").to_vobject
      bs = "\\"
      expect(text).to include("NOTE:a#{bs}#{bs}b#{bs},c#{bs};d#{bs}ne\r\n")
    end

    it "writes structured values with empty trailing fields" do
      name = VformatSpecModels::PersonName.new(family: "Doe")
      text = card_class.new(n: name).to_vobject
      expect(text).to include("N:Doe;;\r\n")
    end

    it "omits nil attributes" do
      text = card_class.new(fn: "Jo").to_vobject
      expect(text).to eq("BEGIN:VCARD\r\nFN:Jo\r\nEND:VCARD\r\n")
    end

    it "writes a parameter value needing quotes as quoted" do
      tel = VformatSpecModels::Phone.new(number: "1", types: ["a,b"])
      text = card_class.new(tel: [tel]).to_vobject
      expect(text).to include("TEL;TYPE=\"a,b\":1\r\n")
    end
  end

  it "round-trips model to text to model" do
    card = card_class.new(
      fn: "Zoë, \"Z\"; Esq.",
      n: VformatSpecModels::PersonName.new(family: "A;B", given: "C,D",
                                           additional: %w[E,F G]),
      tel: [VformatSpecModels::Phone.new(number: "1", types: %w[a b], pref: 2,
                                         group: "g")],
      note: "line1\nline2 \\ end",
      verified: false, score: 0.1, tz: -3600,
      photo: Lutaml::Vformat::Value::Binary::Blob.new("bin\x00"),
      lang: "zh-Hant-TW",
      bday: Lutaml::Vformat::Value::DateAndOrTime.parse("--0412")
    )
    expect(card_class.from_vobject(card.to_vobject)).to eq(card)
  end

  describe "nested components" do
    let(:calendar_text) do
      <<~VOBJECT.gsub("\n", "\r\n")
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        SUMMARY:Review
        DTSTART:19961022T140000Z
        SEQUENCE:3
        URL:https://example.com/a?b=1,2
        BEGIN:VALARM
        ACTION:DISPLAY
        TRIGGER:-PT15M
        END:VALARM
        BEGIN:VALARM
        ACTION:AUDIO
        END:VALARM
        END:VEVENT
        BEGIN:VEVENT
        SUMMARY:Second
        END:VEVENT
        END:VCALENDAR
      VOBJECT
    end

    it "builds the model tree" do
      calendar = calendar_class.from_vobject(calendar_text)
      expect(calendar.events.map(&:summary)).to eq(%w[Review Second])
      first = calendar.events.first
      expect(first.seq).to eq(3)
      expect(first.start.kind).to eq(:date_time)
      expect(first.url).to eq("https://example.com/a?b=1,2")
      expect(first.alarms.map(&:action)).to eq(%w[DISPLAY AUDIO])
      expect(first.alarms.first.trigger).to eq("-PT15M")
      expect(calendar.events.last.alarms).to be_nil
    end

    it "writes the tree back identically" do
      calendar = calendar_class.from_vobject(calendar_text)
      expect(calendar.to_vobject).to eq(calendar_text)
    end

    it "does not leak a nested component's properties into its parent" do
      calendar = calendar_class.from_vobject(calendar_text)
      expect(calendar.version).to eq("2.0")
      expect(calendar.events.first.summary).to eq("Review")
    end

    it "finds the root among several top-level components" do
      text = "BEGIN:X-OTHER\r\nEND:X-OTHER\r\n#{calendar_text}"
      expect(calendar_class.from_vobject(text).version).to eq("2.0")
    end
  end

  describe "errors" do
    it "wraps malformed input as InvalidFormatError" do
      expect { card_class.from_vobject("BEGIN:VCARD\r\nFN:x\r\n") }
        .to raise_error(Lutaml::Model::InvalidFormatError)
    end

    it "wraps a bad typed value as InvalidFormatError" do
      expect do
        card_class.from_vobject("BEGIN:VCARD\nTZ:nonsense\nEND:VCARD\n")
      end
        .to raise_error(Lutaml::Model::InvalidFormatError, /utc-offset/)
    end

    it "fails when the root component is missing" do
      expect { card_class.from_vobject("BEGIN:VEVENT\nEND:VEVENT\n") }
        .to raise_error(Lutaml::Model::InvalidFormatError, /VCARD/)
    end

    it "refuses to write a model without a component_root" do
      expect { VformatSpecModels::Phone.new(number: "1").to_vobject }
        .to raise_error(Lutaml::Vformat::SerializeError, /component_root/)
    end
  end

  describe "value_type: on a mapping rule" do
    let(:tagged_class) do
      Class.new(Lutaml::Model::Serializable) do
        attribute :home, :string
        attribute :age, :string

        vobject do
          type :component
          component_root "X-TAGGED"
          map_property "HOME", to: :home, value_type: :uri
          map_property "AGE", to: :age, value_type: :integer
        end
      end
    end

    it "validates with the named type on read" do
      expect do
        tagged_class.from_vobject("BEGIN:X-TAGGED\nAGE:old\nEND:X-TAGGED\n")
      end
        .to raise_error(Lutaml::Model::InvalidFormatError, /integer/)
    end

    it "does not text-escape a uri-typed value on write" do
      text = tagged_class.new(home: "https://e.com/a,b;c").to_vobject
      expect(text).to include("HOME:https://e.com/a,b;c\r\n")
    end
  end
end
