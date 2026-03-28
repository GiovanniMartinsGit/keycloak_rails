# frozen_string_literal: true

module KeycloakRails
  module Logging
    private

    def logger
      KeycloakRails.configuration.logger
    end

    def log_info(message)
      logger&.info("[KeycloakRails] #{message}")
    end

    def log_error(message)
      logger&.error("[KeycloakRails] #{message}")
    end

    def log_debug(message)
      logger&.debug("[KeycloakRails] #{message}")
    end

    def log_warn(message)
      logger&.warn("[KeycloakRails] #{message}")
    end
  end
end
