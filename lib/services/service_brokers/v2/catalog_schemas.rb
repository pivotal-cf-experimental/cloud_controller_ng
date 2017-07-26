require 'json-schema'

module VCAP::Services::ServiceBrokers::V2
  MAX_SCHEMA_SIZE = 65_536
  class CatalogSchemas
    attr_reader :errors, :create_instance

    def initialize(schema)
      @errors = VCAP::Services::ValidationErrors.new
      create_schema = validate_and_populate_create_instance(schema)
      return if !create_schema
      @create_instance = Schema.new(create_schema, 'service_instance.create.parameters')

      if create_instance
        if !create_instance.validate
          create_instance.errors.messages.each { |key, value| value.each { |error| errors.add(error) } }
        end
      end
    end

    def valid?
      errors.empty?
    end

    private

    def validate_and_populate_create_instance(schemas)
      return unless schemas
      unless schemas.is_a? Hash
        errors.add("Schemas must be a hash, but has value #{schemas.inspect}")
        return
      end

      path = []
      ['service_instance', 'create', 'parameters'].each do |key|
        path += [key]
        schemas = schemas[key]
        return nil unless schemas

        unless schemas.is_a? Hash
          errors.add("Schemas #{path.join('.')} must be a hash, but has value #{schemas.inspect}")
          return nil
        end
      end
      schemas
    end
  end

  class Schema
    include ActiveModel::Validations

    validate :validate_schema_size, :validate_metaschema
    validate :validate_no_external_references, :validate_schema_type

    def initialize(schema, path)
      @schema = schema
      @path = path
    end

    def validate_schema_type
      return unless errors.blank?
      add_schema_error_msg(:schema_type, 'must have field "type", with value "object"') if @schema['type'] != 'object'
    end

    def validate_schema_size
      return unless errors.blank?
      errors.add(:schema_size, "Schema #{@path} is larger than 64KB") if @schema.to_json.length > MAX_SCHEMA_SIZE
    end

    def validate_metaschema
      return unless errors.blank?
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)
      file = File.read(JSON::Validator.validator_for_name('draft4').metaschema)

      metaschema = JSON.parse(file)

      begin
        errors = JSON::Validator.fully_validate(metaschema, @schema)
      rescue => e
        add_schema_error_msg(:schema_err, e)
        return nil
      end

      errors.each do |error|
        add_schema_error_msg(:schema_draft04, "Must conform to JSON Schema Draft 04: #{error}")
      end
    end

    def validate_no_external_references
      return unless errors.blank?
      JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: false)

      begin
        JSON::Validator.validate!(@schema, {})
      rescue JSON::Schema::SchemaError => e
        add_schema_error_msg(:schema_custom_metaschema, "Custom meta schemas are not supported: #{e}")
      rescue JSON::Schema::ReadRefused => e
        add_schema_error_msg(:schema_external_refs, "No external references are allowed: #{e}")
      rescue JSON::Schema::ValidationError
        # We don't care if our input fails validation on broker schema
      rescue => e
        add_schema_error_msg(:schema_err, e)
      end
    end

    def add_schema_error_msg(key, err)
      errors.add(key, "Schema #{@path} is not valid. #{err}")
    end

    def to_json
      @schema.to_json
    end
  end
end
