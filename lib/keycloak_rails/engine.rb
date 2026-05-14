# frozen_string_literal: true

module KeycloakRails
  class Engine < ::Rails::Engine
    isolate_namespace KeycloakRails

    initializer "keycloak_rails.middleware" do |app|
      app.middleware.use KeycloakRails::Middleware::SessionManager
    end

    initializer "keycloak_rails.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include KeycloakRails::Controllers::Concerns::Authentication
      end

      ActiveSupport.on_load(:action_view) do
        include KeycloakRails::Helpers::ViewHelper
      end
    end

    # Auto-mount only for the :default scope (backward compatibility).
    # Named scopes (e.g. :servidor, :cidadao) MUST be mounted manually in the
    # application's routes.rb, passing the scope name via `defaults:`:
    #
    #   mount KeycloakRails::Engine, at: "/keycloak/servidor",
    #         as: "keycloak_servidor",
    #         defaults: { keycloak_scope: "servidor" }
    #
    #   mount KeycloakRails::Engine, at: "/keycloak/cidadao",
    #         as: "keycloak_cidadao",
    #         defaults: { keycloak_scope: "cidadao" }
    initializer "keycloak_rails.append_routes" do |app|
      app.routes.append do
        mount KeycloakRails::Engine, at: "/keycloak"
      end
    end
  end
end
