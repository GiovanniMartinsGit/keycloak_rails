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
