require 'spec_helper'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe CatalogSchemas do
    describe 'initializing catalog schemas' do
      subject { CatalogSchemas.new(attrs) }

      context 'service instance' do
        context 'when catalog has schemas' do
          let(:attrs) { { 'service_instance' => {} } }

          context 'when schemas is not set' do
            {
                'Schemas is nil': nil,
                'Schemas is empty': {},
                'Schemas service_instance is nil': { 'service_instance' => nil },
                'Schemas service_instance is empty': { 'service_instance' => {} },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:update_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when schemas is invalid' do
            {
                'Schemas': true,
                'Schemas service_instance': { 'service_instance' => true }
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end
        end

        context 'when catalog has a create schema' do
          let(:path) { 'service_instance.create.parameters' }
          let(:create_instance_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } }
          let(:attrs) { { 'service_instance' => { 'create' => { 'parameters' => create_instance_schema } } } }

          context 'when attrs have nil value' do
            {
                'Schemas service_instance.create': { 'service_instance' => { 'create' => nil } },
                'Schemas service_instance.create.parameters': { 'service_instance' => { 'create' => { 'parameters' => nil } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:create_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when attrs have a missing key' do
            {
                'Schemas service_instance.create': { 'service_instance' => { 'create' => {} } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:create_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when attrs have an invalid type' do
            {
                'Schemas service_instance.create': { 'service_instance' => { 'create' => true } },
                'Schemas service_instance.create.parameters': { 'service_instance' => { 'create' => { 'parameters' => true } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:create_instance) { should be_nil }
                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end

          context 'when the schema does not conform to JSON Schema Draft 04' do
            let(:create_instance_schema) { { 'properties': true } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') {
              should match "Schema #{path} is not valid\. Must conform to JSON Schema Draft 04.+properties"
            }
          end

          context 'when the schema does not conform to JSON Schema Draft 04 with multiple problems' do
            let(:create_instance_schema) { { 'type': 'foo', 'properties': true } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(2).items }
            its('errors.messages.first') { should match 'properties' }
            its('errors.messages.second') { should match 'type' }
          end

          context 'when the schema has an external schema' do
            let(:create_instance_schema) { { '$schema': 'http://example.com/schema' } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') {
              should match "Schema #{path} is not valid\. Custom meta schemas are not supported.+http://example.com/schema"
            }
          end

          context 'when attrs has a potentially dangerous uri' do
            let(:attrs) {
              {
                  'service_instance' => {
                      'create' => {
                          'parameters' => 'https://example.com/hax0r'
                      }
                  }
              }
            }

            its(:create_instance) { should be_nil }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should eq "Schemas #{path} must be a hash, but has value \"https://example.com/hax0r\"" }
            its(:valid?) { should be false }
          end

          context 'when the schema has an external uri reference' do
            let(:create_instance_schema) { { '$ref': 'http://example.com/ref' } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') {
              should match "Schema #{path} is not valid\. No external references are allowed.+http://example.com/ref"
            }
          end

          context 'when the schema has an external file reference' do
            let(:create_instance_schema) { { '$ref': 'path/to/schema.json' } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') {
              should match "Schema #{path} is not valid\. No external references are allowed.+path/to/schema.json"
            }
          end

          context 'when the schema has an internal reference' do
            let(:create_instance_schema) {
              {
                  'type' => 'object',
                  'properties': {
                      'foo': { 'type': 'integer' },
                      'bar': { '$ref': '#/properties/foo' }
                  }
              }
            }

            its(:valid?) { should be true }
            its(:errors) { should be_empty }
          end

          context 'when the schema has multiple valid constraints ' do
            let(:create_instance_schema) {
              {
                  :'$schema' => 'http://json-schema.org/draft-04/schema#',
                  'type' => 'object',
                  :properties => { 'foo': { 'type': 'string' } },
                  :required => ['foo']
              }
            }

            its(:create_instance) {
              should eq(
                {
                    :'$schema' => 'http://json-schema.org/draft-04/schema#',
                    'type' => 'object',
                    :properties => { foo: { type: 'string' } },
                    :required => ['foo']
                }
                     )
            }
            its(:valid?) { should be true }
            its(:errors) { should be_empty }
          end

          describe 'schema sizes' do
            context 'that are valid' do
              {
                  'well below the limit': 1,
                  'just below the limit': 63,
                  'on the limit': 64,
              }.each do |desc, size_in_kb|
                context "when the schema is #{desc}" do
                  let(:create_instance_schema) { create_schema_of_size(size_in_kb * 1024) }

                  its(:valid?) { should be true }
                  its(:errors) { should be_empty }

                  it 'does perform further validation' do
                    expect_any_instance_of(CatalogSchemas).to receive(:validate_metaschema)
                    expect_any_instance_of(CatalogSchemas).to receive(:validate_no_external_references)
                    subject
                  end
                end
              end
            end

            context 'that are invalid' do
              {
                  'just above the limit': 65,
                  'well above the limit': 10 * 1024,
              }.each do |desc, size_in_kb|
                context "when the schema is #{desc}" do
                  path = 'service_instance.create.parameters'
                  let(:create_instance_schema) { create_schema_of_size(size_in_kb * 1024) }

                  its(:valid?) { should be false }
                  its('errors.messages') { should have(1).items }
                  its('errors.messages.first') { should match "Schema #{path} is not valid. Must not be larger than 64KB" }

                  it 'does not perform further validation' do
                    expect_any_instance_of(CatalogSchemas).to_not receive(:validate_metaschema)
                    expect_any_instance_of(CatalogSchemas).to_not receive(:validate_no_external_references)
                    subject
                  end
                end
              end
            end
          end

          context 'when the schema does not have a type field' do
            let(:create_instance_schema) { { '$schema': 'http://json-schema.org/draft-04/schema#' } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should match "Schema #{path} is not valid\.+ must have field \"type\", with value \"object\"" }
          end

          context 'when the schema has an unknown parse error' do
            before do
              allow(JSON::Validator).to receive(:validate!) { raise 'some unknown error' }
            end

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should match "Schema #{path} is not valid\.+ some unknown error" }
          end
        end

        context 'when catalog has an update schema' do
          let(:path) { 'service_instance.update.parameters' }
          let(:update_instance_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } }
          let(:attrs) { { 'service_instance' => { 'update' => { 'parameters' => update_instance_schema } } } }

          context 'when attrs have nil value' do
            {
                'Schemas service_instance.update': { 'service_instance' => { 'update' => nil } },
                'Schemas service_instance.update.parameters': { 'service_instance' => { 'update' => { 'parameters' => nil } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:update_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when attrs have a missing key' do
            {
                'Schemas service_instance.update': { 'service_instance' => { 'update' => {} } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:update_instance) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when attrs have an invalid type' do
            {
                'Schemas service_instance.update': { 'service_instance' => { 'update' => true } },
                'Schemas service_instance.update.parameters': { 'service_instance' => { 'update' => { 'parameters' => true } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:update_instance) { should be_nil }
                its('errors.messages') { should have(1).items }
                its('errors.messages.first') { should eq "#{name} must be a hash, but has value true" }
                its(:valid?) { should be false }
              end
            end
          end

          context 'when the schema does not conform to JSON Schema Draft 04' do
            let(:update_instance_schema) { { 'properties': true } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') {
              should match "Schema #{path} is not valid\. Must conform to JSON Schema Draft 04.+properties"
            }
          end

          context 'when the schema does not conform to JSON Schema Draft 04 with multiple problems' do
            let(:update_instance_schema) { { 'type': 'foo', 'properties': true } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(2).items }
            its('errors.messages.first') { should match 'properties' }
            its('errors.messages.second') { should match 'type' }
          end

          context 'when the schema has an external schema' do
            let(:update_instance_schema) { { '$schema': 'http://example.com/schema' } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') {
              should match "Schema #{path} is not valid\. Custom meta schemas are not supported.+http://example.com/schema"
            }
          end

          context 'when attrs has a potentially dangerous uri' do
            let(:attrs) {
              {
                  'service_instance' => {
                      'update' => {
                          'parameters' => 'https://example.com/hax0r'
                      }
                  }
              }
            }

            its(:update_instance) { should be_nil }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should eq "Schemas #{path} must be a hash, but has value \"https://example.com/hax0r\"" }
            its(:valid?) { should be false }
          end

          context 'when the schema has an external uri reference' do
            let(:update_instance_schema) { { '$ref': 'http://example.com/ref' } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') {
              should match "Schema #{path} is not valid\. No external references are allowed.+http://example.com/ref"
            }
          end

          context 'when the schema has an external file reference' do
            let(:update_instance_schema) { { '$ref': 'path/to/schema.json' } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') {
              should match "Schema #{path} is not valid\. No external references are allowed.+path/to/schema.json"
            }
          end

          context 'when the schema has an internal reference' do
            let(:update_instance_schema) {
              {
                  'type' => 'object',
                  'properties': {
                      'foo': { 'type': 'integer' },
                      'bar': { '$ref': '#/properties/foo' }
                  }
              }
            }

            its(:valid?) { should be true }
            its(:errors) { should be_empty }
          end

          context 'when the schema has multiple valid constraints ' do
            let(:update_instance_schema) {
              {
                  :'$schema' => 'http://json-schema.org/draft-04/schema#',
                  'type' => 'object',
                  :properties => { 'foo': { 'type': 'string' } },
                  :required => ['foo']
              }
            }

            its(:update_instance) {
              should eq(
                {
                    :'$schema' => 'http://json-schema.org/draft-04/schema#',
                    'type' => 'object',
                    :properties => { foo: { type: 'string' } },
                    :required => ['foo']
                }
                     )
            }
            its(:valid?) { should be true }
            its(:errors) { should be_empty }
          end

          describe 'schema sizes' do
            context 'that are valid' do
              {
                  'well below the limit': 1,
                  'just below the limit': 63,
                  'on the limit': 64,
              }.each do |desc, size_in_kb|
                context "when the schema is #{desc}" do
                  let(:update_instance_schema) { create_schema_of_size(size_in_kb * 1024) }

                  its(:valid?) { should be true }
                  its(:errors) { should be_empty }

                  it 'does perform further validation' do
                    expect_any_instance_of(CatalogSchemas).to receive(:validate_metaschema)
                    expect_any_instance_of(CatalogSchemas).to receive(:validate_no_external_references)
                    subject
                  end
                end
              end
            end

            context 'that are invalid' do
              {
                  'just above the limit': 65,
                  'well above the limit': 10 * 1024,
              }.each do |desc, size_in_kb|
                context "when the schema is #{desc}" do
                  path = 'service_instance.update.parameters'
                  let(:update_instance_schema) { create_schema_of_size(size_in_kb * 1024) }

                  its(:valid?) { should be false }
                  its('errors.messages') { should have(1).items }
                  its('errors.messages.first') { should match "Schema #{path} is not valid. Must not be larger than 64KB" }

                  it 'does not perform further validation' do
                    expect_any_instance_of(CatalogSchemas).to_not receive(:validate_metaschema)
                    expect_any_instance_of(CatalogSchemas).to_not receive(:validate_no_external_references)
                    subject
                  end
                end
              end
            end
          end

          context 'when the schema does not have a type field' do
            let(:update_instance_schema) { { '$schema': 'http://json-schema.org/draft-04/schema#' } }

            its(:valid?) { should be false }
            its('errors.messages') { should have(1).items }
            its('errors.messages.first') { should match "Schema #{path} is not valid\.+ must have field \"type\", with value \"object\"" }
          end
        end
      end

      context 'service binding' do
        context 'when catalog has schemas' do
          let(:create_binding_schema) { }
          let(:attrs) { { 'service_binding' => { 'create' => { 'parameters' => create_binding_schema } } } }

          context 'when the schema has multiple valid constraints ' do
            let(:create_binding_schema) {
              {
                :'$schema' => 'http://json-schema.org/draft-04/schema#',
                'type' => 'object',
                :properties => { 'foo': { 'type': 'string' } },
                :required => ['foo']
              }
            }

            its(:create_binding) {
              should eq(
                       {
                         :'$schema' => 'http://json-schema.org/draft-04/schema#',
                         'type' => 'object',
                         :properties => { foo: { type: 'string' } },
                         :required => ['foo']
                       }
                     )
            }
            its(:valid?) { should be true }
            its(:errors) { should be_empty }
          end

          context 'when attrs have nil value' do
            {
              'Schemas service_binding.create': { 'service_binding' => { 'create' => nil } },
              'Schemas service_binding.create.parameters': { 'service_binding' => { 'create' => { 'parameters' => nil } } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:create_binding) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end

          context 'when attrs have a missing key' do
            {
              'Schemas service_binding.create': { 'service_binding' => { 'create' => {} } },
            }.each do |name, test|
              context "for property #{name}" do
                let(:attrs) { test }

                its(:create_binding) { should be_nil }
                its(:errors) { should be_empty }
                its(:valid?) { should be true }
              end
            end
          end
        end
      end

      def create_schema_of_size(bytes)
        surrounding_bytes = 26
        {
            'type' => 'object',
            'foo' => 'x' * (bytes - surrounding_bytes)
        }
      end
    end
  end
end
