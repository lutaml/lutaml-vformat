# frozen_string_literal: true

RSpec.describe Lutaml::Vformat::Structured do
  describe ".split" do
    it "splits fields on semicolons" do
      expect(described_class.split("Doe;John;;Dr.")).to eq(
        [["Doe"], ["John"], [""], ["Dr."]],
      )
    end

    it "splits values within a field on commas" do
      expect(described_class.split("a,b;c")).to eq([%w[a b], ["c"]])
    end

    it "ignores escaped separators and unescapes them" do
      expect(described_class.split("a\\;b;c\\,d,e")).to eq(
        [["a;b"], ["c,d", "e"]],
      )
    end

    it "keeps an escaped backslash before a separator as a real separator" do
      expect(described_class.split("a\\\\;b")).to eq([["a\\"], ["b"]])
    end

    it "keeps trailing empty fields" do
      expect(described_class.split("a;;")).to eq([["a"], [""], [""]])
    end
  end

  describe ".join" do
    it "joins fields and values with escaping" do
      expect(described_class.join(["a;b", %w[c d], nil])).to eq("a\\;b;c,d;")
    end
  end

  it "round-trips" do
    fields = [["Doe; Jr."], ["a,b", "c"], [""]]
    expect(described_class.split(described_class.join(fields))).to eq(fields)
  end
end
