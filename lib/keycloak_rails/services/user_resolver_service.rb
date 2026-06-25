# frozen_string_literal: true

module KeycloakRails
  module Services
    class UserResolverService < BaseService
            def call(user_info)
        # Log temporário com todos os dados retornados pelo provedor (Keycloak/Gov.br)
        log_info("=== DADOS EXTRAÍDOS DO GOV.BR/KEYCLOAK ===")
        log_info(user_info.inspect)
        log_info("==========================================")

        email = user_info["email"]
        keycloak_id = user_info["sub"]
        cpf_value = user_info["cpf"] || user_info["preferred_username"]

        raise UserNotFoundError.new("Dados do usuário incompletos", user_info: user_info) if keycloak_id.blank?

        log_info("Resolvendo usuário na aplicação")

        user = find_user(email, cpf_value)

        if user.nil? && config.create_user_on_first_login
          user = create_user(email, keycloak_id, user_info)
        end

        raise UserNotFoundError.new("Usuário não encontrado na aplicação", user_info: user_info) if user.nil?

        sync_keycloak_id(user, keycloak_id)
        user
      end

      private

      def find_user(email, cpf_value = nil)
        user = nil
        
        # Tenta buscar por CPF se a configuração existir e houver um CPF
        if config.model_cpf_field.present? && cpf_value.present?
          # Remove formatações caso seja um CPF válido para buscar adequadamente
          cpf_limpo = cpf_value.gsub(/\D/, '')
          if cpf_limpo.length == 11 || cpf_limpo.length == 14
             user = config.resource_model.where("REPLACE(REPLACE(REPLACE(#{config.model_cpf_field}, '.', ''), '-', ''), '/', '') = ?", cpf_limpo).first
          else
             user = config.resource_model.find_by(config.model_cpf_field => cpf_value)
          end
        end

        # Se não encontrar por CPF, tenta por e-mail, como fallback
        if user.nil? && email.present?
          user = config.resource_model.find_by(config.model_email_field => email)
        end

        user
      end

      def create_user(email, keycloak_id, user_info)
        log_info("Criando usuário na aplicação")
        
        attributes = {
          config.model_email_field => email,
          :keycloak_id => keycloak_id,
          config.model_name_field => user_info["name"] || user_info["preferred_username"]
        }

        if config.model_cpf_field.present?
          cpf_value = user_info["cpf"] || user_info["preferred_username"]
          attributes[config.model_cpf_field] = cpf_value if cpf_value.present?
        end

        config.resource_model.create!(attributes)
      rescue ActiveRecord::RecordInvalid => e
        log_error("Erro ao criar usuário: #{e.message}")
        nil
      end

      def sync_keycloak_id(user, keycloak_id)
        return if user.keycloak_id == keycloak_id

        log_info("Atualizando vínculo do usuário com o provedor de identidade")
        user.update!(keycloak_id: keycloak_id)
      end
    end
  end
end
