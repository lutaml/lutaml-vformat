# frozen_string_literal: true

module Lutaml
  module Vformat
    class Error < StandardError; end

    # Malformed vObject input. Registered as the format's error type, so
    # Model.from_vobject surfaces it as Lutaml::Model::InvalidFormatError.
    class ParseError < Error; end

    # A value that does not match its declared vObject value type.
    class ValueError < ParseError; end

    # A model or document that cannot be written as vObject.
    class SerializeError < Error; end
  end
end
