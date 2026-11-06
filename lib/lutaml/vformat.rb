# frozen_string_literal: true

require "lutaml/model"
require_relative "vformat/version"
require_relative "vformat/element_type"
require_relative "vformat/text"
require_relative "vformat/value_types"
require_relative "vformat/parser"
require_relative "vformat/document"
require_relative "vformat/mapping_rule"
require_relative "vformat/mapping"
require_relative "vformat/transform"

module Lutaml
  # The vObject wire format (vCard, iCalendar) for Lutaml::Model.
  #
  # Loading this gem registers the :vobject format into
  # Lutaml::Model::FormatRegistry, which defines the +vobject+ mapping
  # DSL on Serializable models:
  #
  #   class Vcard < Lutaml::Model::Serializable
  #     attribute :fn, :string
  #
  #     vobject do
  #       type :component
  #       component_root "VCARD"
  #       map_property "FN", to: :fn
  #     end
  #   end
  #
  #   Vcard.from_vobject("BEGIN:VCARD\nFN:Name\nEND:VCARD")
  module Vformat
    # Register the format with the core.
    def self.register!
      return if Lutaml::Model::FormatRegistry.registered?(:vobject)

      Lutaml::Model::FormatRegistry.register(
        :vobject,
        mapping_class: Lutaml::Vformat::Mapping,
        adapter_class: Lutaml::Vformat::Adapter,
        transformer: Lutaml::Vformat::Transform,
      )
    end

    register!
  end
end
