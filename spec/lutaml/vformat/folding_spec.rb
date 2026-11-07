# frozen_string_literal: true

RSpec.describe Lutaml::Vformat::Folding do
  describe ".fold" do
    it "leaves a line of exactly 75 octets alone" do
      line = "A" * 75
      expect(described_class.fold(line)).to eq(line)
    end

    it "folds a line of 76 octets into 75 and 1 plus the leading space" do
      line = "A" * 76
      expect(described_class.fold(line)).to eq("#{'A' * 75}\r\n A")
    end

    it "keeps every physical line at or under 75 octets, space included" do
      folded = described_class.fold("N:#{'x' * 500}")
      lines = folded.split("\r\n")
      expect(lines.map(&:bytesize)).to all(be <= 75)
      expect(lines.first.bytesize).to eq(75)
      expect(lines.drop(1)).to all(start_with(" "))
      expect(lines[1].bytesize).to eq(75)
    end

    it "counts octets, not characters" do
      line = "X:#{'é' * 40}" # 2 + 80 octets, 42 characters
      folded = described_class.fold(line)
      expect(folded).to include("\r\n ")
      expect(folded.split("\r\n").map(&:bytesize)).to all(be <= 75)
    end

    it "never splits a two-byte sequence" do
      # 74 ASCII octets then é: byte 75 would be inside the sequence
      line = "#{'a' * 74}é"
      folded = described_class.fold(line)
      expect(folded).to eq("#{'a' * 74}\r\n é")
      expect(folded.split("\r\n")).to all(satisfy(&:valid_encoding?))
    end

    it "never splits a three-byte sequence" do
      line = "#{'a' * 73}€tail"
      folded = described_class.fold(line)
      expect(folded.split("\r\n").first).to eq("a" * 73)
      expect(folded.split("\r\n")).to all(satisfy(&:valid_encoding?))
    end

    it "never splits a four-byte sequence" do
      line = "#{'a' * 72}😀tail"
      folded = described_class.fold(line)
      expect(folded.split("\r\n").first).to eq("a" * 72)
      expect(folded.split("\r\n")).to all(satisfy(&:valid_encoding?))
    end

    it "fills a line exactly when a multibyte character ends on the boundary" do
      line = "#{'a' * 73}éxyz"
      folded = described_class.fold(line)
      expect(folded.split("\r\n").first.bytesize).to eq(75)
    end

    it "round-trips long multibyte text through unfold" do
      line = "NOTE:#{'日本語のテキスト' * 30}"
      expect(described_class.unfold(described_class.fold(line))).to eq(line)
    end

    it "returns UTF-8 text" do
      expect(described_class.fold("é" * 100).encoding).to eq(Encoding::UTF_8)
    end

    it "honours a custom line ending" do
      expect(described_class.fold("A" * 80,
                                  eol: "\n")).to eq("#{'A' * 75}\n AAAAA")
    end
  end

  describe ".unfold" do
    it "removes CRLF followed by a space" do
      expect(described_class.unfold("AB\r\n CD")).to eq("ABCD")
    end

    it "removes CRLF followed by a tab" do
      expect(described_class.unfold("AB\r\n\tCD")).to eq("ABCD")
    end

    it "accepts bare LF folds" do
      expect(described_class.unfold("AB\n CD")).to eq("ABCD")
    end

    it "removes only one whitespace character per fold" do
      expect(described_class.unfold("AB\r\n  CD")).to eq("AB CD")
    end

    it "leaves unfolded line breaks alone" do
      expect(described_class.unfold("AB\r\nCD")).to eq("AB\r\nCD")
    end
  end
end
