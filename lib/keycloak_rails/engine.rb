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

    initializer "keycloak_rails.append_routes" do |app|
      app.routes.append do
        mount KeycloakRails::Engine, at: "/keycloak"
      end
    end
  end
end
