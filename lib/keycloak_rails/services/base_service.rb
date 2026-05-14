# frozen_string_literal: true

module KeycloakRails
  module Services
    class BaseService
      include Logging

      def initialize(scope: :default)
        @scope = scope.to_sym
      end

      private

      def config
        KeycloakRails.configuration(@scope)
      end

      def http_client
        @http_client ||= Http::Client.new(config: config)
      end

      # Use the scoped logger so each authentication domain can log independently.
      def logger
        config.logger
      end
    end
  end
end
