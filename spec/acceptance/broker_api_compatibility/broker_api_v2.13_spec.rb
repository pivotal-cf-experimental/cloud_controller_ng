require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.13' do
    include VCAP::CloudController::BrokerApiHelper

    let(:create_instance_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } }
    let(:update_instance_schema) { { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } }
    let(:create_binding_schema)  { { '$schema' => 'http://json-schema.org/draft-04/schema#', 'type' => 'object' } }
    let(:schemas) {
      {
        'service_instance' => {
          'create' => {
            'parameters' => create_instance_schema
          },
          'update' => {
            'parameters' => update_instance_schema
          }
        },
        'service_binding' => {
          'create' => {
            'parameters' => create_binding_schema
          }
        }
      }
    }

    let(:catalog) { default_catalog(plan_schemas: schemas) }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    context 'when a broker catalog defines a service instance' do
      context 'with a valid create schema' do
        let(:create_instance_schema) {
          {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object'
          }
        }

        it 'responds with the schema for a service plan entry' do
          get("/v2/service_plans/#{@plan_guid}",
              {}.to_json,
              json_headers(admin_headers))

          parsed_body = MultiJson.load(last_response.body)
          create_schema = parsed_body['entity']['schemas']['service_instance']['create']
          expect(create_schema).to eq(
            {
              'parameters' =>
              {
                '$schema' => 'http://json-schema.org/draft-04/schema#',
                'type' => 'object'
              }
            }
          )
        end
      end

      context 'with a valid update schema' do
        let(:update_instance_schema) {
          {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object'
          }
        }

        it 'responds with the schema for a service plan entry' do
          get("/v2/service_plans/#{@plan_guid}",
              {}.to_json,
              json_headers(admin_headers))

          parsed_body = MultiJson.load(last_response.body)
          update_schema = parsed_body['entity']['schemas']['service_instance']['update']
          expect(update_schema).to eq(
            {
              'parameters' =>
              {
                '$schema' => 'http://json-schema.org/draft-04/schema#',
                'type' => 'object'
              }
            }
          )
        end
      end

      context 'with an invalid create schema' do
        before do
          update_broker(default_catalog(plan_schemas: { 'service_instance' => { 'create' => true } }))
        end

        it 'returns an error' do
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['code']).to eq(270012)
          expect(parsed_body['description']).to include('Schemas service_instance.create must be a hash, but has value true')
        end
      end

      context 'with an invalid update schema' do
        before do
          update_broker(default_catalog(plan_schemas: { 'service_instance' => { 'update' => true } }))
        end

        it 'returns an error' do
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['code']).to eq(270012)
          expect(parsed_body['description']).to include('Schemas service_instance.update must be a hash, but has value true')
        end
      end
    end

    context 'when a broker catalog defines a service binding' do
      context 'with a valid create schema' do
        let(:create_binding_schema) {
          {
            '$schema' => 'http://json-schema.org/draft-04/schema#',
            'type' => 'object'
          }
        }

        it 'responds with the schema for a service plan entry' do
          get("/v2/service_plans/#{@plan_guid}",
              {}.to_json,
              json_headers(admin_headers))

          parsed_body = MultiJson.load(last_response.body)
          create_schema = parsed_body['entity']['schemas']['service_binding']['create']
          expect(create_schema).to eq(
            {
              'parameters' =>
              {
                '$schema' => 'http://json-schema.org/draft-04/schema#',
                'type' => 'object'
              }
            }
          )
        end
      end

      context 'with an invalid create schema' do
        before do
          update_broker(default_catalog(plan_schemas: { 'service_binding' => { 'create' => true } }))
        end

        it 'returns an error' do
          parsed_body = MultiJson.load(last_response.body)

          expect(parsed_body['code']).to eq(270012)
          expect(parsed_body['description']).to include('Schemas service_binding.create must be a hash, but has value true')
        end
      end
    end

    context 'when the broker catalog defines a plan without plan schemas' do
      it 'responds with an empty schema' do
        get("/v2/service_plans/#{@large_plan_guid}",
            {}.to_json,
            json_headers(admin_headers)
           )

        parsed_body = MultiJson.load(last_response.body)
        expect(parsed_body['entity']['schemas']).
          to eq(
            {
              'service_instance' => {
                'create' => {
                  'parameters' => {}
                },
                'update' => {
                  'parameters' => {}
                }
              },
              'service_binding' => {
                'create' => {
                  'parameters' => {}
                }
              }
            }
        )
      end
    end

    describe 'service binding contains context object' do
      context 'for binding to an application' do
        before do
          provision_service
          create_app
          bind_service
        end

        it 'receives a context object' do
          expected_body = hash_including(:context)
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_id}}).with(body: expected_body)
          ).to have_been_made
        end

        it 'receives the correct attributes in the context' do
          expected_body = hash_including(context: {
            platform: 'cloudfoundry',
            organization_guid: @org_guid,
            space_guid: @space_guid,
          })

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_id}}).with(body: expected_body)
          ).to have_been_made
        end
      end

      context 'for create service key' do
        before do
          provision_service
          create_service_key
        end

        it 'receives a context object' do
          expected_body = hash_including(:context)
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_id}}).with(body: expected_body)
          ).to have_been_made
        end

        it 'receives the correct attributes in the context' do
          expected_body = hash_including(context: {
            platform: 'cloudfoundry',
            organization_guid: @org_guid,
            space_guid: @space_guid,
          })

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_id}}).with(body: expected_body)
          ).to have_been_made
        end
      end

      context 'for bind route service' do
        let(:catalog) { default_catalog(requires: ['route_forwarding']) }
        let(:route) { VCAP::CloudController::Route.make(space: @space) }
        before do
          provision_service
          create_route_binding(route)
        end

        it 'receives a context object' do
          expected_body = hash_including(:context)
          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_id}}).with(body: expected_body)
          ).to have_been_made
        end

        it 'receives the correct attributes in the context' do
          expected_body = hash_including(context: {
            platform: 'cloudfoundry',
            organization_guid: @org_guid,
            space_guid: @space_guid,
          })

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/#{@binding_id}}).with(body: expected_body)
          ).to have_been_made
        end
      end
    end
  end
end
