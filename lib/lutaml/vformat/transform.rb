# frozen_string_literal: true

module Lutaml
  module Vformat
    # The transformer registered for :vobject: models from a parsed Document
    # and Documents from models.
    class Transform < Lutaml::Model::Transform
      def self.data_to_model(context, data, _format, options = {})
        new(context, options[:register]).data_to_model(data)
      end

      def self.model_to_data(context, model, _format, options = {})
        new(context, options[:register]).model_to_data(model)
      end

      def data_to_model(document)
        mapping = context.mappings_for(:vobject)
        name = mapping.component_name
        root = document.components.find { |c| name.nil? || c.name == name }
        unless root
          raise ParseError,
                "no #{name || 'component'} component in the input"
        end

        ModelReader.new(lutaml_register).component(context, root)
      end

      def model_to_data(model)
        name = context.mappings_for(:vobject).component_name
        unless name
          raise SerializeError,
                "#{context} declares no component_root, so it cannot be " \
                "written as a top-level component"
        end

        writer = ModelWriter.new(lutaml_register)
        Document.new([writer.component(name, context, model)])
      end
    end
  end
end
