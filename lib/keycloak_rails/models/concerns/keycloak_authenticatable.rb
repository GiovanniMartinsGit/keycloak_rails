# frozen_string_literal: true

require "active_support/concern"

module KeycloakRails
  module Models
    module Concerns
      module KeycloakAuthenticatable
        extend ActiveSupport::Concern

        included do
          validates :email, presence: true, uniqueness: true
          validates :keycloak_id, uniqueness: true, allow_nil: true

          scope :with_keycloak, -> { where.not(keycloak_id: nil) }
          scope :without_keycloak, -> { where(keycloak_id: nil) }
        end

        def keycloak_linked?
          keycloak_id.present?
        end

        def link_keycloak!(keycloak_sub)
          update!(keycloak_id: keycloak_sub)
        end

        
        def assign_attributes_from_keycloak(user_info, scope = :default)
          config = KeycloakRails.configuration(scope)
          
          self.keycloak_id = user_info["sub"] if self.respond_to?(:keycloak_id=)

          if config.model_email_field.present? && self.respond_to?("#{config.model_email_field}=")
            self.send("#{config.model_email_field}=", user_info["email"]) if self.send(config.model_email_field).blank?
          end

          if config.model_name_field.present? && self.respond_to?("#{config.model_name_field}=")
            self.send("#{config.model_name_field}=", user_info["name"] || user_info["preferred_username"]) if self.send(config.model_name_field).blank?
          end

          if config.model_cpf_field.present? && self.respond_to?("#{config.model_cpf_field}=")
            cpf_value = user_info["cpf"] || user_info["preferred_username"]
            self.send("#{config.model_cpf_field}=", cpf_value) if self.send(config.model_cpf_field).blank? && cpf_value.present?
          end
        end

        def unlink_keycloak!
          update!(keycloak_id: nil)
        end

        class_methods do
          def find_by_keycloak_id(keycloak_id)
            find_by(keycloak_id: keycloak_id)
          end

          def find_by_email_for_keycloak(email)
            find_by(email: email)
          end
        end
      end
    end
  end
end
