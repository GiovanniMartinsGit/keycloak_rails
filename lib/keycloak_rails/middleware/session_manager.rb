# frozen_string_literal: true

module KeycloakRails
  module Middleware
    class SessionManager
      include Logging

      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if skip_path?(request.path)
          return @app.call(env)
        end

        # Iterate over every explicitly configured scope so that, in a
        # multi-scope app, both :servidor and :cidadao sessions are refreshed
        # independently on each request.
        KeycloakRails.scopes.each do |scope|
          user_id_key = Configuration.session_key_for(:user_id, scope)
          user_id     = request.session[user_id_key]

          if user_id.present?
            handle_existing_session(env, request, user_id, scope)
          else
            env[env_key(:authenticated, scope)] = false
          end
        end

        @app.call(env)
      end

      private

      def handle_existing_session(env, request, user_id, scope)
        token_data = TokenStore.read(user_id, scope: scope)

        unless token_data
          env[env_key(:authenticated, scope)] = false
          return
        end

        token_service = Services::TokenService.new(scope: scope)

        if token_service.token_expired?(token_data["access_token"])
          refresh_session(env, request, user_id, token_data, token_service, scope)
        else
          env[env_key(:authenticated,  scope)] = true
          env[env_key(:access_token,   scope)] = token_data["access_token"]
          env[env_key(:user_id,        scope)] = user_id
        end
      rescue StandardError => e
        log_error("Erro no middleware de sessão (scope=#{scope}): #{e.message}")
        env[env_key(:authenticated, scope)] = false
      end

      def refresh_session(env, request, user_id, old_token_data, token_service, scope)
        log_info("Token expirado, tentando renovar... (scope=#{scope})")

        new_token_data = token_service.refresh_token(old_token_data["refresh_token"])
        TokenStore.store(user_id, new_token_data, scope: scope)

        env[env_key(:authenticated,  scope)] = true
        env[env_key(:access_token,   scope)] = new_token_data["access_token"]
        env[env_key(:user_id,        scope)] = user_id

        log_info("Token renovado com sucesso (scope=#{scope})")
      rescue StandardError => e
        log_warn("Falha ao renovar token (scope=#{scope}): #{e.message}")
        TokenStore.delete(user_id, scope: scope)
        clear_session(request, scope)
        env[env_key(:authenticated, scope)] = false
      end

      def clear_session(request, scope)
        request.session.delete(Configuration.session_key_for(:user_id, scope))
      end

      def skip_path?(path)
        # Skip the engine's own paths.  Named scopes should be mounted under
        # /keycloak/* (the default), or users can add custom patterns to
        # skip_paths in their scope configuration.
        return true if path.start_with?("/keycloak")

        KeycloakRails.scopes.any? do |scope|
          KeycloakRails.configuration(scope).skip_paths.any? { |pattern| path.match?(pattern) }
        end
      end

      # Build a Rack env key.
      # :default scope keeps the original key names for backward compatibility:
      #   "keycloak_rails.authenticated", "keycloak_rails.access_token", etc.
      # Named scopes use a namespaced variant:
      #   "keycloak_rails.servidor.authenticated", etc.
      def env_key(name, scope)
        scope == :default ? "keycloak_rails.#{name}" : "keycloak_rails.#{scope}.#{name}"
      end
    end
  end
end

