# frozen_string_literal: true

module KeycloakRails
  class SessionsController < ActionController::Base
    include Logging

    protect_from_forgery with: :exception, except: [:callback]

    def new
      state = SecureRandom.hex(24)
      session[oauth_state_key] = state

      authorize_url = build_authorize_url(state)
      log_info("Redirecionando para Keycloak para autenticação (scope=#{current_scope})")

      if request.headers["Turbo-Frame"].present? || request.media_type == "text/vnd.turbo-stream.html"
        render html: "<html><body><script>window.location.replace(#{authorize_url.to_json})</script></body></html>".html_safe, layout: false
      else
        redirect_to authorize_url, allow_other_host: true
      end
    end

    def callback
      validate_state!

      token_data = exchange_code_for_tokens
      user_info  = fetch_user_info(token_data["access_token"])
      validate_permission!(token_data["access_token"])
      user = resolve_user(user_info)

      create_session(token_data, user)
      log_info("Login realizado com sucesso (scope=#{current_scope})")

      redirect_to after_sign_in_path
    rescue AuthenticationError, TokenInvalidError => e
      log_error("Erro de autenticação no callback: #{e.message}")
      handle_authentication_error(e)
    rescue PermissionDeniedError => e
      log_error("Acesso negado durante a autenticação")
      session[authenticated_key] = true
      handle_permission_error(e)
    rescue UserNotFoundError => e
      log_error("Usuário não encontrado: #{e.message}")
      handle_user_not_found_error(e)
    end

    def destroy
      user_id = session[user_id_key]
      id_token_value = nil

      if user_id
        id_token_value      = TokenStore.id_token(user_id, scope: current_scope)
        refresh_token_value = TokenStore.refresh_token(user_id, scope: current_scope)
        revoke_keycloak_session(refresh_token_value) if refresh_token_value
        TokenStore.delete(user_id, scope: current_scope)
      end

      session.delete(user_id_key)
      session.delete(authenticated_key)
      session.delete(oauth_state_key)
      session.delete(return_to_key)

      log_info("Logout realizado (scope=#{current_scope})")

      redirect_to build_logout_url(id_token_value), allow_other_host: true, status: :see_other
    end

    private

    # ── Scope resolution ──────────────────────────────────────────────────────

    # Resolves the authentication scope from the route default (:keycloak_scope).
    # Security (OWASP A01 – Broken Access Control):
    #   The value is injected by Rails routing (via `defaults:`) and then
    #   validated against the set of explicitly registered scopes.  An attacker
    #   cannot forge a request that references an unregistered scope because we
    #   raise AuthenticationError before any credential exchange occurs.
    def current_scope
      @current_scope ||= begin
        raw = params[:keycloak_scope].presence
        return :default if raw.blank?

        scope_sym = raw.to_sym
        unless KeycloakRails.scope_configured?(scope_sym)
          raise AuthenticationError, "Escopo de autenticação inválido"
        end

        scope_sym
      end
    end

    def keycloak_config
      KeycloakRails.configuration(current_scope)
    end

    # Use the scoped logger (OWASP A09 – Security Logging and Monitoring Failures)
    def logger
      keycloak_config.logger
    end

    # ── Session key helpers ───────────────────────────────────────────────────

    def user_id_key
      Configuration.session_key_for(:user_id, current_scope)
    end

    def authenticated_key
      Configuration.session_key_for(:authenticated, current_scope)
    end

    def oauth_state_key
      Configuration.session_key_for(:oauth_state, current_scope)
    end

    def return_to_key
      Configuration.session_key_for(:return_to, current_scope)
    end

    # ── OAuth / OIDC helpers ──────────────────────────────────────────────────

    def build_authorize_url(state)
      params = URI.encode_www_form(
        response_type: "code",
        client_id:     keycloak_config.client_id,
        redirect_uri:  callback_url,
        scope:         "openid email profile",
        state:         state
      )
      "#{keycloak_config.auth_url}?#{params}"
    end

    def build_logout_url(id_token = nil)
      logout_params = { client_id: keycloak_config.client_id, post_logout_redirect_uri: main_app.root_url }
      logout_params[:id_token_hint] = id_token if id_token

      "#{keycloak_config.logout_url}?#{URI.encode_www_form(logout_params)}"
    end

    def revoke_keycloak_session(refresh_token_value)
      token_service.revoke_token(refresh_token_value)
    rescue StandardError => e
      log_warn("Falha ao revogar sessão no Keycloak: #{e.message}")
    end

    def validate_state!
      expected_state = session.delete(oauth_state_key)
      received_state = params[:state]

      # Security (OWASP A01 – CSRF via OAuth state mismatch):
      #   Each scope stores its state under an isolated session key, so states
      #   from different scopes cannot be cross-validated.
      if expected_state.blank? || received_state != expected_state
        raise AuthenticationError, "State OAuth inválido"
      end
    end

    def exchange_code_for_tokens
      code = params[:code]
      raise AuthenticationError, "Authorization code não recebido" if code.blank?

      token_service.exchange_code(code, callback_url)
    end

    def fetch_user_info(access_token)
      user_info_service.call(access_token)
    end

    def validate_permission!(access_token)
      return if keycloak_config.permission_name.blank?

      unless permission_service.user_has_permission?(access_token)
        raise PermissionDeniedError, "Usuário não autorizado para esta aplicação"
      end
    end

    def resolve_user(user_info)
      user_resolver_service.call(user_info)
    end

    def create_session(token_data, user)
      TokenStore.store(user.id, token_data, scope: current_scope)
      session[user_id_key] = user.id
    end

    def callback_url
      keycloak_rails.callback_url
    end

    def after_sign_in_path
      stored = session.delete(return_to_key)
      # Security (OWASP A01 – Open Redirect): only allow own-origin relative paths
      if stored.present? && stored.start_with?("/") && !stored.start_with?("//")
        stored
      else
        keycloak_config.after_sign_in_path
      end
    end

    def handle_authentication_error(_error)
      flash[:alert] = "Falha na autenticação. Tente novamente."
      redirect_to main_app.root_path
    end

    def handle_permission_error(_error)
      flash[:alert] = "Você não possui permissão para acessar esta aplicação."
      redirect_to resolve_permission_denied_path
    end

    def handle_user_not_found_error(_error)
      flash[:alert] = "Usuário não encontrado na aplicação. Contate o administrador."
      redirect_to main_app.root_path
    end

    # ── Services ──────────────────────────────────────────────────────────────

    def token_service
      @token_service ||= Services::TokenService.new(scope: current_scope)
    end

    def user_info_service
      @user_info_service ||= Services::UserInfoService.new(scope: current_scope)
    end

    def permission_service
      @permission_service ||= Services::PermissionService.new(scope: current_scope)
    end

    def user_resolver_service
      @user_resolver_service ||= Services::UserResolverService.new(scope: current_scope)
    end

    def resolve_permission_denied_path
      configured_path = keycloak_config.permission_denied_path

      case configured_path
      when Proc
        instance_exec(&configured_path)
      when Symbol
        return main_app.public_send(configured_path) if main_app.respond_to?(configured_path)
        return public_send(configured_path) if respond_to?(configured_path, true)

        raise ConfigurationError, "Rota configurada em permission_denied_path não existe: #{configured_path}"
      else
        configured_path
      end
    end
  end
end
