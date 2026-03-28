# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails do
  describe ".configure" do
    it "permite configurar via bloco" do
      KeycloakRails.configure do |config|
        config.server_url = "http://novo-keycloak.test"
        config.realm = "novo-realm"
        config.client_id = "novo-client"
        config.client_secret = "novo-secret"
      end

      expect(KeycloakRails.configuration.server_url).to eq("http://novo-keycloak.test")
      expect(KeycloakRails.configuration.realm).to eq("novo-realm")
      expect(KeycloakRails.configuration.client_id).to eq("novo-client")
    end
  end

  describe ".reset_configuration!" do
    it "reseta a configuração para os valores padrão" do
      KeycloakRails.configure do |config|
        config.server_url = "http://custom.test"
        config.client_id = "custom"
        config.client_secret = "secret"
      end

      KeycloakRails.reset_configuration!
      expect(KeycloakRails.configuration.resource_model_class_name).to eq("User")
    end
  end

  describe "errors" do
    it "AuthenticationError herda de Error" do
      expect(KeycloakRails::AuthenticationError.superclass).to eq(KeycloakRails::Error)
    end

    it "TokenExpiredError herda de AuthenticationError" do
      expect(KeycloakRails::TokenExpiredError.superclass).to eq(KeycloakRails::AuthenticationError)
    end

    it "HttpError armazena status e response_body" do
      error = KeycloakRails::HttpError.new("msg", status: 500, response_body: "error")
      expect(error.status).to eq(500)
      expect(error.response_body).to eq("error")
    end
  end
end
