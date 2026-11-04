# frozen_string_literal: true

# Generic vObject models for the specs. These exercise the mapping DSL; they
# are not a vCard vocabulary.
module VformatSpecModels
  class Phone < Lutaml::Model::Serializable
    attribute :number, :string
    attribute :types, :string, collection: true
    attribute :pref, :integer
    attribute :group, :string

    vobject do
      type :property
      map_value to: :number
      map_param "TYPE", to: :types
      map_param "PREF", to: :pref
      map_group to: :group
    end
  end

  class PersonName < Lutaml::Model::Serializable
    attribute :family, :string
    attribute :given, :string
    attribute :additional, :string, collection: true

    vobject do
      type :property
      map_field 0, to: :family
      map_field 1, to: :given
      map_field 2, to: :additional
    end
  end

  class Alarm < Lutaml::Model::Serializable
    attribute :action, :string
    attribute :trigger, :string

    vobject do
      type :component
      component_root "VALARM"
      map_property "ACTION", to: :action
      map_property "TRIGGER", to: :trigger
    end
  end

  class Event < Lutaml::Model::Serializable
    attribute :summary, :string
    attribute :description, :string
    attribute :start, Lutaml::Vformat::Value::DateAndOrTime
    attribute :seq, :integer
    attribute :url, Lutaml::Vformat::Value::Uri
    attribute :alarms, Alarm, collection: true

    vobject do
      type :component
      component_root "VEVENT"
      map_property "SUMMARY", to: :summary
      map_property "DESCRIPTION", to: :description
      map_property "DTSTART", to: :start
      map_property "SEQUENCE", to: :seq
      map_property "URL", to: :url
      map_component "VALARM", to: :alarms
    end
  end

  class Calendar < Lutaml::Model::Serializable
    attribute :version, :string
    attribute :events, Event, collection: true

    vobject do
      type :component
      component_root "VCALENDAR"
      map_property "VERSION", to: :version
      map_component "VEVENT", to: :events
    end
  end

  class Card < Lutaml::Model::Serializable
    attribute :fn, :string
    attribute :n, PersonName
    attribute :tel, Phone, collection: true
    attribute :note, :string
    attribute :verified, :boolean
    attribute :score, :float
    attribute :photo, Lutaml::Vformat::Value::Binary
    attribute :tz, Lutaml::Vformat::Value::UtcOffset
    attribute :lang, Lutaml::Vformat::Value::LanguageTag
    attribute :bday, Lutaml::Vformat::Value::DateAndOrTime

    vobject do
      type :component
      component_root "VCARD"
      map_property "FN", to: :fn
      map_property "N", to: :n
      map_property "TEL", to: :tel
      map_property "NOTE", to: :note
      map_property "X-VERIFIED", to: :verified
      map_property "X-SCORE", to: :score
      map_property "PHOTO", to: :photo
      map_property "TZ", to: :tz
      map_property "LANG", to: :lang
      map_property "BDAY", to: :bday
    end
  end
end
