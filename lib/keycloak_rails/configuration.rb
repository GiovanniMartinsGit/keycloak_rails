# frozen_string_literal: true

module KeycloakRails
  class Configuration
    attr_accessor :server_url, :realm, :client_id, :client_secret,
                  :resource_model, :resource_model_class_name,
                  :permission_name, :skip_paths,
                  :token_expiration_tolerance, :logger,
                  :after_sign_in_path, :after_sign_out_path,
                  :create_user_on_first_login,
                  :permission_denied_path, :permission_denied_status,
                  :ssl_verify, :ca_file

    def initialize
      @server_url = ENV.fetch("KEYCLOAK_SERVER_URL", "http://localhost:8080")
      @realm = ENV.fetch("KEYCLOAK_REALM", "master")
      @client_id = ENV.fetch("KEYCLOAK_CLIENT_ID", nil)
      @client_secret = ENV.fetch("KEYCLOAK_CLIENT_SECRET", nil)
      @resource_model_class_name = "User"
      @permission_name = nil
      @skip_paths = []
      @token_expiration_tolerance = 10
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      @after_sign_in_path = "/"
      @after_sign_out_path = "/"
      @create_user_on_first_login = false
      @permission_denied_path = "/"
      @permission_denied_status = :payment_required
      @ssl_verify = true
      @ca_file = nil
    end

    def realm_url
      "#{server_url}/realms/#{realm}"
    end

    def auth_url
      "#{realm_url}/protocol/openid-connect/auth"
    end

    def token_url
      "#{realm_url}/protocol/openid-connect/token"
    end

    def userinfo_url
      "#{realm_url}/protocol/openid-connect/userinfo"
    end

    def introspect_url
      "#{realm_url}/protocol/openid-connect/token/introspect"
    end

    def logout_url
      "#{realm_url}/protocol/openid-connect/logout"
    end

    def certs_url
      "#{realm_url}/protocol/openid-connect/certs"
    end

    def resource_model
      @resource_model ||= begin
        klass = @resource_model_class_name.constantize
        unless klass < ActiveRecord::Base
          raise ConfigurationError, "#{klass} deve herdar de ActiveRecord::Base"
        end
        klass
      end
    end

    def validate!
      raise ConfigurationError, "client_id é obrigatório" if client_id.blank?
      raise ConfigurationError, "client_secret é obrigatório" if client_secret.blank?
      raise ConfigurationError, "server_url é obrigatório" if server_url.blank?
      raise ConfigurationError, "realm é obrigatório" if realm.blank?
      if !ssl_verify && defined?(Rails) && Rails.env.production?
        raise ConfigurationError, "ssl_verify não pode ser false em produção"
      end
    end
  end
end
