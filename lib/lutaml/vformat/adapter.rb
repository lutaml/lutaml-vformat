# frozen_string_literal: true

module Lutaml
  module Vformat
    # The adapter registered for :vobject. Parsing returns an Adapter (a
    # Document); serializing wraps the Document built by the transform.
    class Adapter < Document
    end
  end
end
