# frozen_string_literal: true

module KeycloakRails
  module Helpers
    module ViewHelper
      def keycloak_user_signed_in?
        keycloak_current_user.present?
      end

      def keycloak_session_active?
        # Delegates to the controller concern which is scope-aware.
        keycloak_user_signed_in? || session[keycloak_session_key(:authenticated)] == true
      end

      def keycloak_login_path
        keycloak_route_proxy.login_path
      end

      def keycloak_logout_path
        keycloak_route_proxy.logout_path
      end

      def keycloak_logout_button(text = "Sair", **options)
        html_options = options.reverse_merge(
          method: :delete,
          data: { turbo: false }
        )
        button_to text, keycloak_logout_path, **html_options
      end

      private

      def keycloak_route_proxy
        scope = respond_to?(:keycloak_scope) ? keycloak_scope.to_sym : :default
        return keycloak_rails if scope == :default

        route_proxy = :"keycloak_#{scope}"
        respond_to?(route_proxy, true) ? send(route_proxy) : keycloak_rails
      end
    end
  end
end
