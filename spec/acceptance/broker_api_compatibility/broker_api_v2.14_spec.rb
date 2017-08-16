require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.14' do
    include VCAP::CloudController::BrokerApiHelper

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
end
