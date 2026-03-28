# frozen_string_literal: true

module KeycloakRails
  module Services
    class PermissionService < BaseService
      def user_has_permission?(access_token, permission_name = nil)
        permission = permission_name || keycloak_config.permission_name
        return true if permission.blank?

        log_info("Verificando permissão '#{permission}' nas roles do client '#{keycloak_config.client_id}'")

        decoded = decode_token_payload(access_token)
        client_roles = extract_client_roles(decoded)

        if client_roles.include?(permission)
          log_info("Permissão '#{permission}' concedida (client role encontrada)")
          true
        else
          log_warn("Permissão '#{permission}' negada. Roles do client: #{client_roles.inspect}")
          false
        end
      rescue StandardError => e
        log_error("Erro ao verificar permissão: #{e.message}")
        false
      end

      def user_roles(access_token)
        decoded = decode_token_payload(access_token)
        {
          client_roles: extract_client_roles(decoded),
          realm_roles: extract_realm_roles(decoded)
        }
      end

      private

      def decode_token_payload(access_token)
        Services::TokenService.new.decode_token(access_token)
      end

      def extract_client_roles(decoded)
        client_id = keycloak_config.client_id
        decoded.dig("resource_access", client_id, "roles") || []
      end

      def extract_realm_roles(decoded)
        decoded.dig("realm_access", "roles") || []
      end

      def keycloak_config
        KeycloakRails.configuration
      end
    end
  end
end
