# frozen_string_literal: true

require "lutaml/vformat"

class TelModel < Lutaml::Model::Serializable
  attribute :value, :string
  attribute :type, :string

  vobject do
    type :property
    property_root "TEL"

    map_property "TYPE", to: :type
    map_value to: :value
  end
end

class NameModel < Lutaml::Model::Serializable
  attribute :family, :string
  attribute :given, :string
  attribute :additional, :string
  attribute :prefix, :string
  attribute :suffix, :string

  vobject do
    type :property
    property_root "N"

    map_field_set count: 5, item_type: :list, item_options: { type: :text }
    map_field 0, to: :family
    map_field 1, to: :given
    map_field 2, to: :additional
    map_field 3, to: :prefix
    map_field 4, to: :suffix
  end
end

class BdayModel < Lutaml::Model::Serializable
  attribute :value, Lutaml::Vformat::VobjectValueType::IsoDateAndOrTime

  vobject do
    type :property
    property_root "BDAY"
    map_value to: :value
  end
end

class VcardModel < Lutaml::Model::Serializable
  attribute :version, :string
  attribute :fn, :string
  attribute :n, NameModel
  attribute :tel, TelModel, collection: true
  attribute :email, :string, collection: true
  attribute :bday, BdayModel

  vobject do
    type :component
    component_root "VCARD"

    map_property "VERSION", to: :version
    map_property "FN", to: :fn
    map_property "N", to: :n, type: :structured
    map_property "TEL", to: :tel
    map_property "EMAIL", to: :email
    map_property "BDAY", to: :bday
  end
end

def build_vcard(fn_value:, tel_list: [])
  VcardModel.new(
    version: "4.0",
    fn: fn_value,
    tel: tel_list.map { |t| TelModel.new(value: t) },
    email: [],
  )
end
