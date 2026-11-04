# frozen_string_literal: true

require "lutaml/model"
require_relative "vformat/version"
require_relative "vformat/errors"
require_relative "vformat/folding"
require_relative "vformat/escaping"
require_relative "vformat/structured"
require_relative "vformat/property"
require_relative "vformat/component"
require_relative "vformat/parser"
require_relative "vformat/writer"
require_relative "vformat/document"
require_relative "vformat/value"
require_relative "vformat/codec"
require_relative "vformat/adapter"
require_relative "vformat/mapping_rule"
require_relative "vformat/mapping"
require_relative "vformat/model_support"
require_relative "vformat/model_reader"
require_relative "vformat/model_writer"
require_relative "vformat/transform"

module Lutaml
  # The vObject wire format (vCard, iCalendar) for Lutaml::Model.
  module Vformat
    FORMAT = :vobject

    # Registers :vobject into Lutaml::Model::FormatRegistry. Runs on require;
    # calling it again is a no-op while this gem's registration is in place.
    def self.register!
      registry = Lutaml::Model::FormatRegistry
      return if registry.mappings_class_for(FORMAT) == Mapping

      registry.register(
        FORMAT,
        mapping_class: Mapping,
        adapter_class: Adapter,
        transformer: Transform,
        error_types: [ParseError],
      )
    end

    register!
  end
end
