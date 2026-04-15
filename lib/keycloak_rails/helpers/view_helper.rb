# frozen_string_literal: true

module KeycloakRails
  module Helpers
    module ViewHelper
      def keycloak_user_signed_in?
        keycloak_current_user.present?
      end

      def keycloak_login_path
        keycloak_rails.login_path
      end

      def keycloak_logout_path
        keycloak_rails.logout_path
      end

      def keycloak_logout_button(text = "Sair", **options)
        html_options = options.reverse_merge(
          method: :delete,
          data: { turbo: false }
        )
        button_to text, keycloak_rails.logout_path, **html_options
      end
    end
  end
end
