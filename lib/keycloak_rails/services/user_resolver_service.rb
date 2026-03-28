# frozen_string_literal: true

module KeycloakRails
  module Services
    class UserResolverService < BaseService
      def call(user_info)
        email = user_info["email"]
        keycloak_id = user_info["sub"]

        raise UserNotFoundError, "Email não encontrado nas informações do Keycloak" if email.blank?
        raise UserNotFoundError, "Keycloak ID (sub) não encontrado" if keycloak_id.blank?

        log_info("Resolvendo usuário pelo email: #{email}")

        user = find_user(email)

        if user.nil? && config.create_user_on_first_login
          user = create_user(email, keycloak_id, user_info)
        end

        raise UserNotFoundError, "Usuário com email '#{email}' não encontrado na aplicação" if user.nil?

        sync_keycloak_id(user, keycloak_id)
        user
      end

      private

      def find_user(email)
        config.resource_model.find_by(email: email)
      end

      def create_user(email, keycloak_id, user_info)
        log_info("Criando novo usuário para: #{email}")
        config.resource_model.create!(
          email: email,
          keycloak_id: keycloak_id,
          nome: user_info["name"] || user_info["preferred_username"]
        )
      rescue ActiveRecord::RecordInvalid => e
        log_error("Erro ao criar usuário: #{e.message}")
        nil
      end

      def sync_keycloak_id(user, keycloak_id)
        return if user.keycloak_id == keycloak_id

        log_info("Atualizando keycloak_id do usuário #{user.email}")
        user.update!(keycloak_id: keycloak_id)
      end
    end
  end
end
