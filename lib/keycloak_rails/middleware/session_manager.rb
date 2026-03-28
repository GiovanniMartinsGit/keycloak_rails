# frozen_string_literal: true

module KeycloakRails
  module Middleware
    class SessionManager
      include Logging

      KEYCLOAK_SESSION_KEY = "keycloak_rails"

      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if skip_path?(request.path)
          return @app.call(env)
        end

        user_id = request.session[:_keycloak_user_id]

        if user_id.present?
          handle_existing_session(env, request, user_id)
        else
          env["keycloak_rails.authenticated"] = false
        end

        @app.call(env)
      end

      private

      def handle_existing_session(env, request, user_id)
        token_data = TokenStore.read(user_id)

        unless token_data
          env["keycloak_rails.authenticated"] = false
          return
        end

        token_service = Services::TokenService.new

        if token_service.token_expired?(token_data["access_token"])
          refresh_session(env, request, user_id, token_data, token_service)
        else
          env["keycloak_rails.authenticated"] = true
          env["keycloak_rails.access_token"] = token_data["access_token"]
          env["keycloak_rails.user_id"] = user_id
        end
      rescue StandardError => e
        log_error("Erro no middleware de sessão: #{e.message}")
        env["keycloak_rails.authenticated"] = false
      end

      def refresh_session(env, request, user_id, old_token_data, token_service)
        log_info("Token expirado, tentando renovar...")

        new_token_data = token_service.refresh_token(old_token_data["refresh_token"])
        TokenStore.store(user_id, new_token_data)

        env["keycloak_rails.authenticated"] = true
        env["keycloak_rails.access_token"] = new_token_data["access_token"]
        env["keycloak_rails.user_id"] = user_id

        log_info("Token renovado com sucesso")
      rescue StandardError => e
        log_warn("Falha ao renovar token: #{e.message}")
        TokenStore.delete(user_id)
        clear_session(request)
        env["keycloak_rails.authenticated"] = false
      end

      def clear_session(request)
        request.session.delete(:_keycloak_user_id)
      end

      def skip_path?(path)
        return true if path.start_with?("/keycloak")

        skip_paths = KeycloakRails.configuration.skip_paths
        skip_paths.any? { |pattern| path.match?(pattern) }
      end
    end
  end
end
