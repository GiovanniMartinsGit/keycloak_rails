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

        def keycloak_current_user
          return @_keycloak_current_user if defined?(@_keycloak_current_user)

          user_id = session[:_keycloak_user_id]
          @_keycloak_current_user = user_id.present? ? keycloak_config.resource_model.find_by(id: user_id) : nil
        end

        def current_user
          keycloak_current_user
        end

        def keycloak_user_signed_in?
          keycloak_current_user.present?
        end

        def keycloak_session_active?
          keycloak_user_signed_in? || session[:_keycloak_authenticated] == true
        end

        def authenticate_keycloak_user!
          return if keycloak_user_signed_in?
          return if keycloak_logout_request?

          store_location!
          redirect_to keycloak_rails.login_path, allow_other_host: false
        end

        def sign_out_keycloak_user!
          user_id = session[:_keycloak_user_id]

          if user_id
            refresh_token_value = TokenStore.refresh_token(user_id)
            if refresh_token_value
              begin
                Services::TokenService.new.revoke_token(refresh_token_value)
              rescue StandardError => e
                Rails.logger.warn("[KeycloakRails] Falha ao revogar sessão no Keycloak: #{e.message}")
              end
            end
            TokenStore.delete(user_id)
          end

          session.delete(:_keycloak_user_id)
          session.delete(:_keycloak_authenticated)
          @_keycloak_current_user = nil

          redirect_to keycloak_config.after_sign_out_path
        end

        private

        def keycloak_logout_request?
          request.path == keycloak_rails.logout_path
        rescue NoMethodError
          false
        end

        def store_location!
          path = request.fullpath
          return unless request.get?
          return unless path.start_with?("/") && !path.start_with?("//")

          session[:keycloak_rails_return_to] = path
        end

        def stored_location
          path = session.delete(:keycloak_rails_return_to)
          return nil unless path.present? && path.start_with?("/") && !path.start_with?("//")

          path
        end

        def after_sign_in_path
          stored_location || keycloak_config.after_sign_in_path
        end

        def build_keycloak_logout_url(id_token)
          params = URI.encode_www_form(
            id_token_hint: id_token,
            client_id: keycloak_config.client_id,
            post_logout_redirect_uri: root_url
          )
          "#{keycloak_config.logout_url}?#{params}"
        end

        def keycloak_config
          KeycloakRails.configuration
        end
      end
    end
  end
end
