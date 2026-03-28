# frozen_string_literal: true

module KeycloakRails
  module Services
    class UserInfoService < BaseService
      def call(access_token)
        log_info("Buscando informações do usuário no Keycloak")

        http_client.get(config.userinfo_url, headers: {
          "Authorization" => "Bearer #{access_token}"
        })
      end
    end
  end
end
