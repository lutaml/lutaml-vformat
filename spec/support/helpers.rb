# frozen_string_literal: true

module VformatSpecHelpers
  def parse_vobject(text)
    Lutaml::Vformat::Parser.parse(text)
  end

  def write_vobject(*components)
    Lutaml::Vformat::Writer.write(components)
  end

  def new_property(name, value = "", **options)
    Lutaml::Vformat::Property.new(name, value, **options)
  end

  def new_component(name, **options)
    Lutaml::Vformat::Component.new(name, **options)
  end

  # The physical lines a property is written as, inside a component A.
  def lines_for(property)
    write_vobject(new_component("A", properties: [property])).split("\r\n")
  end

  # The one content line a property is written as, inside a component A.
  def line_for(property)
    lines_for(property)[1]
  end
end

RSpec.configure { |config| config.include VformatSpecHelpers }
