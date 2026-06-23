# frozen_string_literal: true

module KeycloakRails
  class Configuration
    attr_accessor :server_url, :realm, :client_id, :client_secret,
                  :resource_model, :resource_model_class_name,
                  :permission_name, :skip_paths,
                  :token_expiration_tolerance, :logger,
                  :after_sign_in_path, :after_sign_out_path,
                  :create_user_on_first_login,
                  :permission_denied_path, :user_not_found_path,
                  :ssl_verify, :ca_file,
                  :model_email_field, :model_name_field, :model_cpf_field

    attr_reader :scope

    def initialize(scope = :default)
      @scope = scope.to_sym
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
      @user_not_found_path = nil
      @ssl_verify = true
      @ca_file = nil
      @model_email_field = :email
      @model_name_field = :nome
      @model_cpf_field = :cpf
    end

    # Maps a logical session key name to the actual Rails session hash key,
    # preserving backward compatibility for the :default scope.
    #
    # Security (OWASP A01 – Broken Access Control):
    #   Each scope uses isolated session keys, preventing cross-scope session
    #   confusion where a :cidadao session could be mistaken for a :servidor one.
    #
    # :default scope keeps the original key names so existing sessions are
    # not invalidated after upgrading to the multi-scope version.
    def self.session_key_for(name, scope)
      scope = scope.to_sym
      name  = name.to_sym

      if scope == :default
        case name
        when :user_id     then :_keycloak_user_id
        when :authenticated then :_keycloak_authenticated
        when :oauth_state   then :keycloak_oauth_state
        when :return_to     then :keycloak_rails_return_to
        else :"_keycloak_#{name}"
        end
      else
        # Named scopes: _keycloak_<scope>_<name>
        :"_keycloak_#{scope}_#{name}"
      end
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

      # Security (OWASP A05 – Security Misconfiguration):
      # Freeze critical credentials after validation to prevent runtime
      # tampering with authentication parameters (e.g. via mass-assignment
      # or monkey-patching in a compromised dependency).
      @client_id      = @client_id.freeze
      @client_secret  = @client_secret.freeze
      @server_url     = @server_url.freeze
      @realm          = @realm.freeze
      @permission_name = @permission_name.freeze
    end
  end
end
