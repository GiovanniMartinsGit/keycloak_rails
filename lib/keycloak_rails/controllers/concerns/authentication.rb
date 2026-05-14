# frozen_string_literal: true

require "active_support/concern"

module KeycloakRails
  module Controllers
    module Concerns
      module Authentication
        extend ActiveSupport::Concern

        included do
          helper_method :current_user, :keycloak_current_user, :keycloak_user_signed_in?, :keycloak_session_active? if respond_to?(:helper_method)
        end

        # Override in your controller to declare which authentication scope it uses.
        # Defaults to :default for single-scope backward compatibility.
        #
        # Example (Ruby 3.0+ shorthand):
        #   def keycloak_scope = :servidor
        #
        # Example (classic):
        #   def keycloak_scope
        #     :cidadao
        #   end
        def keycloak_scope
          :default
        end

        def keycloak_current_user
          return @_keycloak_current_user if defined?(@_keycloak_current_user)

          user_id = session[keycloak_session_key(:user_id)]
          @_keycloak_current_user = user_id.present? ? keycloak_config.resource_model.find_by(id: user_id) : nil
        end

        def current_user
          keycloak_current_user
        end

        def keycloak_user_signed_in?
          keycloak_current_user.present?
        end

        def keycloak_session_active?
          keycloak_user_signed_in? || session[keycloak_session_key(:authenticated)] == true
        end

        def authenticate_keycloak_user!
          return if keycloak_user_signed_in?
          return if keycloak_logout_request?

          store_location!
          redirect_to keycloak_login_path_for_scope, allow_other_host: false
        end

        def sign_out_keycloak_user!
          user_id = session[keycloak_session_key(:user_id)]
          id_token_value = nil

          if user_id
            id_token_value      = TokenStore.id_token(user_id, scope: keycloak_scope)
            refresh_token_value = TokenStore.refresh_token(user_id, scope: keycloak_scope)
            if refresh_token_value
              begin
                Services::TokenService.new(scope: keycloak_scope).revoke_token(refresh_token_value)
              rescue StandardError => e
                Rails.logger.warn("[KeycloakRails] Falha ao revogar sessão no Keycloak: #{e.message}")
              end
            end
            TokenStore.delete(user_id, scope: keycloak_scope)
          end

          session.delete(keycloak_session_key(:user_id))
          session.delete(keycloak_session_key(:authenticated))
          @_keycloak_current_user = nil

          redirect_to build_keycloak_logout_url(id_token_value), allow_other_host: true
        end

        private

        # Resolves the session hash key for a logical name in this scope.
        def keycloak_session_key(name)
          Configuration.session_key_for(name, keycloak_scope)
        end

        def keycloak_logout_request?
          # Try the scoped logout path helper first; fall back to prefix check.
          begin
            logout = (keycloak_scope == :default) ? keycloak_rails.logout_path : send(:"keycloak_#{keycloak_scope}").logout_path
            request.path == logout
          rescue NoMethodError
            request.path.start_with?("/keycloak")
          end
        end

        def store_location!
          path = request.fullpath
          return unless request.get?
          # Security (OWASP A01 – Open Redirect): only store relative paths
          return unless path.start_with?("/") && !path.start_with?("//")

          session[keycloak_session_key(:return_to)] = path
        end

        def stored_location
          path = session.delete(keycloak_session_key(:return_to))
          # Security: re-validate on read in case session was tampered with
          return nil unless path.present? && path.start_with?("/") && !path.start_with?("//")

          path
        end

        def after_sign_in_path
          stored_location || keycloak_config.after_sign_in_path
        end

        def build_keycloak_logout_url(id_token = nil)
          logout_params = { client_id: keycloak_config.client_id, post_logout_redirect_uri: root_url }
          logout_params[:id_token_hint] = id_token if id_token

          "#{keycloak_config.logout_url}?#{URI.encode_www_form(logout_params)}"
        end

        # Returns the login path for the engine mount that serves this scope.
        # Convention: named scopes are mounted as "keycloak_<scope>" (e.g. keycloak_servidor).
        def keycloak_login_path_for_scope
          return keycloak_rails.login_path if keycloak_scope == :default

          route_proxy = :"keycloak_#{keycloak_scope}"
          respond_to?(route_proxy, true) ? send(route_proxy).login_path : keycloak_rails.login_path
        end

        def keycloak_config
          KeycloakRails.configuration(keycloak_scope)
        end
      end
    end
  end
end
