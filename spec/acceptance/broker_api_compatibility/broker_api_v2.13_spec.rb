require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.13' do
    include VCAP::CloudController::BrokerApiHelper

    describe 'configuration parameter schemas' do
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
    end

    describe 'originating header' do
      let(:catalog) { default_catalog(plan_updateable: true) }

      before do
        setup_cc
        setup_broker(catalog)
        @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
      end

      context 'service broker registration' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          setup_broker_with_user(user)
          @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:get, %r{/v2/catalog}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service provision request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service deprovision request' do
        let(:user) { VCAP::CloudController::User.make }

        before do
          provision_service(user: user)
          deprovision_service(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service update request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service(user: user)
          upgrade_service_instance(200, user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service binding request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service
          create_app
          bind_service(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'service unbind request' do
        let(:user) { VCAP::CloudController::User.make }

        before do
          provision_service
          create_app
          bind_service
          unbind_service(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'create service key request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service
          create_service_key(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'delete service key request' do
        let(:user) { VCAP::CloudController::User.make }
        before do
          provision_service
          create_service_key
          delete_key(user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'create route binding' do
        let(:catalog) { default_catalog(plan_updateable: true, requires: ['route_forwarding']) }
        let(:user) { VCAP::CloudController::User.make }
        let(:route) { VCAP::CloudController::Route.make(space: @space) }

        before do
          provision_service
          create_route_binding(route, user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'delete route binding' do
        let(:catalog) { default_catalog(plan_updateable: true, requires: ['route_forwarding']) }
        let(:user) { VCAP::CloudController::User.make }
        let(:route) { VCAP::CloudController::Route.make(space: @space) }

        before do
          provision_service
          create_route_binding(route, user: user)
          delete_route_binding(route, user: user)
        end

        it 'receives the user_id in the X-Broker-API-Originating-Identity header' do
          base64_encoded_user_id = Base64.strict_encode64("{\"user_id\":\"#{user.guid}\"}")

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_id}"
            end
          ).to have_been_made
        end
      end

      context 'when multiple users operate on a service instance' do
        let(:user_a) { VCAP::CloudController::User.make }
        let(:user_b) { VCAP::CloudController::User.make }
        let(:user_c) { VCAP::CloudController::User.make }

        before do
          provision_service(user: user_a)
          upgrade_service_instance(200, user: user_b)
          deprovision_service(user: user_c)
        end

        it 'has the correct user ids for the requests' do
          base64_encoded_user_a_id = Base64.strict_encode64("{\"user_id\":\"#{user_a.guid}\"}")
          base64_encoded_user_b_id = Base64.strict_encode64("{\"user_id\":\"#{user_b.guid}\"}")
          base64_encoded_user_c_id = Base64.strict_encode64("{\"user_id\":\"#{user_c.guid}\"}")

          expect(
            a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_a_id}"
            end
          ).to have_been_made

          expect(
            a_request(:patch, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_b_id}"
            end
          ).to have_been_made

          expect(
            a_request(:delete, %r{/v2/service_instances/#{@service_instance_guid}}).with do |req|
              req.headers['X-Broker-Api-Originating-Identity'] == "cloudfoundry #{base64_encoded_user_c_id}"
            end
          ).to have_been_made
        end
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
