# frozen_string_literal: true

module KeycloakRails
  module Services
    class TokenIntrospectionService < BaseService
      def call(access_token)
        log_info("Realizando introspecção do token")

        http_client.post(config.introspect_url, body: {
          token: access_token,
          client_id: config.client_id,
          client_secret: config.client_secret
        })
      end

      def active?(access_token)
        result = call(access_token)
        active = result["active"] == true
        log_info("Token #{active ? 'ativo' : 'inativo'}")
        active
      rescue HttpError => e
        log_error("Erro ao introspectar token: #{e.message}")
        false
      end
    end
  end
end
