# frozen_string_literal: true

module DiasporaFederation
  module Parsers
    # This is a parser of JSON serialized object. JSON object format is defined by
    # JSON schema which is available at https://diaspora.github.io/diaspora_federation/schemas/federation_entities.json.
    # TODO: We must publish the schema at a real URL
    class JsonParser < BaseParser
      # @see BaseParser#parse
      # @param [Hash] json_hash A hash acquired by running JSON.parse with JSON serialized entity
      # @return [Array[1]] comprehensive data for an entity instantiation
      def parse(json_hash)
        from_json_sanity_validation(json_hash)
        parse_entity_data(json_hash["entity_data"])
      end

      private

      def parse_entity_data(entity_data)
        hash = entity_data.map {|key, value|
          property = entity_type.find_property_for_xml_name(key)
          if property
            type = entity_type.class_props[property]
            [property, parse_element_from_value(type, entity_data[key])]
          else
            [key, value]
          end
        }.to_h

        [hash]
      end

      def parse_element_from_value(type, value)
        return if value.nil?

        if %i[integer boolean timestamp].include?(type) && !value.is_a?(String)
          value
        elsif type.instance_of?(Symbol)
          parse_string(type, value)
        elsif type.instance_of?(Array)
          raise DeserializationError, "Expected array for #{type}" unless value.respond_to?(:map)

          value.map {|element|
            type.first.from_json(element)
          }
        elsif type.ancestors.include?(Entity)
          type.from_json(value)
        end
      end

      def from_json_sanity_validation(json_hash)
        missing = %w[entity_type entity_data].map {|prop|
          prop if json_hash[prop].nil?
        }.compact.join(", ")
        raise DeserializationError, "Required properties are missing in JSON object: #{missing}" unless missing.empty?

        assert_parsability_of(json_hash["entity_type"])
      end

      # Raised when the format of the input JSON data doesn't match the parser's expectations
      class DeserializationError < RuntimeError
      end
    end
  end
end
