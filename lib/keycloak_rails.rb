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
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      configuration.validate!
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
