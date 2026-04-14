# frozen_string_literal: true

module KeycloakRails
  class SessionsController < ActionController::Base
    include Logging

    protect_from_forgery with: :exception, except: [:callback]

    def new
      state = SecureRandom.hex(24)
      session[:keycloak_oauth_state] = state

      authorize_url = build_authorize_url(state)
      log_info("Redirecionando para Keycloak para autenticação")

      if request.headers["Turbo-Frame"].present? || request.media_type == "text/vnd.turbo-stream.html"
        render html: "<html><body><script>window.location.replace(#{authorize_url.to_json})</script></body></html>".html_safe, layout: false
      else
        redirect_to authorize_url, allow_other_host: true
      end
    end

    def callback
      validate_state!

      token_data = exchange_code_for_tokens
      user_info = fetch_user_info(token_data["access_token"])
      validate_permission!(token_data["access_token"])
      user = resolve_user(user_info)

      create_session(token_data, user)
      log_info("Login realizado com sucesso para: #{user.email}")

      redirect_to after_sign_in_path
    rescue AuthenticationError, TokenInvalidError => e
      log_error("Erro de autenticação no callback: #{e.message}")
      handle_authentication_error(e)
    rescue PermissionDeniedError => e
      log_error("Permissão negada: #{e.message}")
      handle_permission_error(e)
    rescue UserNotFoundError => e
      log_error("Usuário não encontrado: #{e.message}")
      handle_user_not_found_error(e)
    end

    def destroy
      user_id = session[:_keycloak_user_id]

      if user_id
        refresh_token_value = TokenStore.refresh_token(user_id)
        revoke_keycloak_session(refresh_token_value) if refresh_token_value
        TokenStore.delete(user_id)
      end

      session.delete(:_keycloak_user_id)
      session.delete(:keycloak_oauth_state)
      session.delete(:keycloak_rails_return_to)

      log_info("Logout realizado")

      redirect_to keycloak_config.after_sign_out_path, status: :see_other
    end

    private

    def build_authorize_url(state)
      params = URI.encode_www_form(
        response_type: "code",
        client_id: keycloak_config.client_id,
        redirect_uri: callback_url,
        scope: "openid email profile",
        state: state
      )
      "#{keycloak_config.auth_url}?#{params}"
    end

    def build_logout_url(id_token)
      params = URI.encode_www_form(
        id_token_hint: id_token,
        client_id: keycloak_config.client_id,
        post_logout_redirect_uri: main_app.root_url
      )
      "#{keycloak_config.logout_url}?#{params}"
    end

    def revoke_keycloak_session(refresh_token_value)
      token_service.revoke_token(refresh_token_value)
    rescue StandardError => e
      log_warn("Falha ao revogar sessão no Keycloak: #{e.message}")
    end

    def validate_state!
      expected_state = session.delete(:keycloak_oauth_state)
      received_state = params[:state]

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
        raise PermissionDeniedError,
              "Usuário não possui a permissão '#{keycloak_config.permission_name}' no client '#{keycloak_config.client_id}'"
      end
    end

    def resolve_user(user_info)
      user_resolver_service.call(user_info)
    end

    def create_session(token_data, user)
      TokenStore.store(user.id, token_data)
      session[:_keycloak_user_id] = user.id
    end

    def callback_url
      keycloak_rails.callback_url
    end

    def after_sign_in_path
      stored = session.delete(:keycloak_rails_return_to)
      if stored.present? && stored.start_with?("/") && !stored.start_with?("//")
        stored
      else
        keycloak_config.after_sign_in_path
      end
    end

    def handle_authentication_error(error)
      flash[:alert] = "Falha na autenticação. Tente novamente."
      redirect_to main_app.root_path
    end

    def handle_permission_error(error)
      flash[:alert] = "Você não possui permissão para acessar esta aplicação."
      redirect_to resolve_permission_denied_path, status: keycloak_config.permission_denied_status
    end

    def handle_user_not_found_error(error)
      flash[:alert] = "Usuário não encontrado na aplicação. Contate o administrador."
      redirect_to main_app.root_path
    end

    def token_service
      @token_service ||= Services::TokenService.new
    end

    def user_info_service
      @user_info_service ||= Services::UserInfoService.new
    end

    def permission_service
      @permission_service ||= Services::PermissionService.new
    end

    def user_resolver_service
      @user_resolver_service ||= Services::UserResolverService.new
    end

    def keycloak_config
      KeycloakRails.configuration
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
