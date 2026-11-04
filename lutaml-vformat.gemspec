# frozen_string_literal: true

require_relative "lib/lutaml/vformat/version"

Gem::Specification.new do |spec|
  spec.name = "lutaml-vformat"
  spec.version = Lutaml::Vformat::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "vObject wire format (RFC 6350 / RFC 5545 style) for " \
                 "Lutaml::Model"
  spec.description = <<~DESC
    Parses and serializes the vObject wire format used by vCard and iCalendar:
    BEGIN/END component nesting, property parameters, structured values, text
    escaping and 75-octet line folding, with the vObject value types. Registers
    the :vobject format into Lutaml::Model::FormatRegistry when required.
  DESC

  spec.homepage = "https://github.com/lutaml/lutaml-vformat"
  spec.license = "BSD-2-Clause"

  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features|\.github)/})
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "lutaml-model", "~> 0.8.164"
end
