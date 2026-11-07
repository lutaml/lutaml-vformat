# frozen_string_literal: true

RSpec.describe Lutaml::Vformat::Mapping do
  subject(:mapping) { described_class.new }

  it "accepts component and property element types" do
    expect { mapping.type(:component) }.not_to raise_error
    expect { mapping.type(:property) }.not_to raise_error
  end

  it "rejects other element types" do
    expect { mapping.type(:widget) }.to raise_error(ArgumentError, /widget/)
  end

  it "upper-cases root names" do
    mapping.component_root("vcard")
    expect(mapping.component_name).to eq("VCARD")
  end

  it "records rules by kind" do
    mapping.map_property("fn", to: :fn)
    mapping.map_component("VEVENT", to: :events)
    mapping.map_value(to: :value)
    mapping.map_param("type", to: :types)
    mapping.map_field(1, to: :given)
    mapping.map_group(to: :group)
    kinds = mapping.mappings.map { |r| [r.kind, r.name] }
    expect(kinds).to eq(
      [[:property, "FN"], [:component, "VEVENT"], [:value, "VALUE"],
       [:param, "TYPE"], [:field, 1], [:group, "GROUP"]],
    )
  end

  it "keeps roots and rules in a deep copy" do
    mapping.type(:component)
    mapping.component_root("A")
    mapping.map_property("X", to: :x, value_type: :uri)
    copy = mapping.deep_dup
    expect(copy.component_name).to eq("A")
    expect(copy.element_type).to eq(:component)
    expect(copy.rules(:property).first.value_type).to eq(:uri)
    expect(copy.mappings.first).not_to equal(mapping.mappings.first)
  end
end
