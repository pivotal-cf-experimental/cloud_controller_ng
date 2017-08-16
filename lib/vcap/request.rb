module VCAP
  module Request
    HEADER_NAME = 'X-VCAP-Request-ID'.freeze
    HEADER_BROKER_API_VERSION = 'X-Broker-Api-Version'.freeze
    HEADER_API_INFO_LOCATION = 'X-Api-Info-Location'.freeze
    HEADER_BROKER_API_ORIGINATING_IDENTITY = 'X-Broker-Api-Originating-Identity'.freeze

    class << self
      def current_id=(request_id)
        Thread.current[:vcap_request_id] = request_id
        if request_id.nil?
          Steno.config.context.data.delete('request_guid')
        else
          Steno.config.context.data['request_guid'] = request_id
        end
      end

      def current_id
        Thread.current[:vcap_request_id]
      end
    end
  end
end
