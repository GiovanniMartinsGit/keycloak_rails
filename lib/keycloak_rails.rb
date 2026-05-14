# frozen_string_literal: true

require "faraday"
require "jwt"
require "logger"

require "keycloak_rails/version"
require "keycloak_rails/errors"
require "keycloak_rails/logging"
require "keycloak_rails/configuration"
require "keycloak_rails/http/client"
require "keycloak_rails/services/base_service"
require "keycloak_rails/services/token_service"
require "keycloak_rails/services/user_info_service"
require "keycloak_rails/services/permission_service"
require "keycloak_rails/services/token_introspection_service"
require "keycloak_rails/services/user_resolver_service"
require "keycloak_rails/token_store"
require "keycloak_rails/middleware/session_manager"
require "keycloak_rails/models/concerns/keycloak_authenticatable"
require "keycloak_rails/controllers/concerns/authentication"
require "keycloak_rails/helpers/view_helper"
require "keycloak_rails/engine" if defined?(Rails)

module KeycloakRails
  class << self
    # Returns the configuration for +scope+.
    # Scope :default is fully backward-compatible with the old single-config API.
    # If the scope was never explicitly configured, returns a temporary
    # default Configuration (not registered), so that `scopes` stays clean.
    def configuration(scope = :default)
      scope = scope.to_sym
      @configurations ||= {}
      @configurations[scope] || Configuration.new(scope)
    end

    # Yields a Configuration for +scope+ and validates it.
    # KeycloakRails.configure { |c| }            → scope :default (backward compat)
    # KeycloakRails.configure(:servidor) { |c| } → named scope
    def configure(scope = :default)
      scope = scope.to_sym
      @configurations ||= {}
      @configurations[scope] ||= Configuration.new(scope)
      yield(@configurations[scope])
      @configurations[scope].validate!
      @configurations[scope]
    end

    # Returns the list of scopes that have been explicitly configured.
    def scopes
      (@configurations || {}).keys
    end

    # Returns true when +scope+ has been explicitly configured.
    def scope_configured?(scope)
      scopes.include?(scope.to_sym)
    end

    # Resets the configuration for a single scope (useful in tests).
    def reset_configuration!(scope = :default)
      (@configurations ||= {}).delete(scope.to_sym)
    end

    # Resets ALL scope configurations (useful in tests).
    def reset_all_configurations!
      @configurations = {}
    end
  end
end
