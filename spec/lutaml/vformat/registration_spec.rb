# frozen_string_literal: true

RSpec.describe "format registration" do
  let(:registry) { Lutaml::Model::FormatRegistry }

  it "registers :vobject on require" do
    expect(registry).to be_registered(:vobject)
  end

  it "registers this gem's mapping, adapter and transformer" do
    expect(registry.mappings_class_for(:vobject)).to eq(Lutaml::Vformat::Mapping)
    expect(registry.adapter_class_for(:vobject)).to eq(Lutaml::Vformat::Adapter)
    expect(registry.transformer_for(:vobject)).to eq(Lutaml::Vformat::Transform)
  end

  it "declares ParseError as the format's error type" do
    expect(registry.error_types_for(:vobject)).to eq([Lutaml::Vformat::ParseError])
  end

  it "gives models from_vobject and to_vobject" do
    expect(VformatSpecModels::Card).to respond_to(:from_vobject)
    expect(VformatSpecModels::Card.new).to respond_to(:to_vobject)
  end

  it "does not warn or replace the registration when registered again" do
    expect { Lutaml::Vformat.register! }.not_to output.to_stderr
    expect(registry.mappings_class_for(:vobject)).to eq(Lutaml::Vformat::Mapping)
  end

  it "is not a key-value or RDF format" do
    expect(registry.key_value?(:vobject)).to be(false)
    expect(registry.rdf?(:vobject)).to be(false)
  end
end
