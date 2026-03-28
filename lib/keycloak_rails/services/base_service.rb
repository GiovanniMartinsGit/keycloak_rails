# frozen_string_literal: true

module KeycloakRails
  module Services
    class BaseService
      include Logging

      private

      def config
        KeycloakRails.configuration
      end

      def http_client
        @http_client ||= Http::Client.new
      end
    end
  end
end
