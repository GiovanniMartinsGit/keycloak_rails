# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "define valores padrão" do
      expect(config.server_url).to be_present
      expect(config.realm).to eq("master")
      expect(config.resource_model_class_name).to eq("User")
      expect(config.token_expiration_tolerance).to eq(10)
      expect(config.after_sign_in_path).to eq("/")
      expect(config.after_sign_out_path).to eq("/")
      expect(config.permission_denied_path).to eq("/")
      expect(config.create_user_on_first_login).to be false
      expect(config.skip_paths).to eq([])
    end
  end

  describe "URLs" do
    before do
      config.server_url = "http://keycloak.test"
      config.realm = "meu-realm"
    end

    it "gera realm_url corretamente" do
      expect(config.realm_url).to eq("http://keycloak.test/realms/meu-realm")
    end

    it "gera auth_url corretamente" do
      expect(config.auth_url).to eq("http://keycloak.test/realms/meu-realm/protocol/openid-connect/auth")
    end

    it "gera token_url corretamente" do
      expect(config.token_url).to eq("http://keycloak.test/realms/meu-realm/protocol/openid-connect/token")
    end

    it "gera userinfo_url corretamente" do
      expect(config.userinfo_url).to eq("http://keycloak.test/realms/meu-realm/protocol/openid-connect/userinfo")
    end

    it "gera introspect_url corretamente" do
      expect(config.introspect_url).to eq("http://keycloak.test/realms/meu-realm/protocol/openid-connect/token/introspect")
    end

    it "gera logout_url corretamente" do
      expect(config.logout_url).to eq("http://keycloak.test/realms/meu-realm/protocol/openid-connect/logout")
    end

    it "gera certs_url corretamente" do
      expect(config.certs_url).to eq("http://keycloak.test/realms/meu-realm/protocol/openid-connect/certs")
    end
  end

  describe "#resource_model" do
    it "retorna a classe do modelo" do
      config.resource_model_class_name = "User"
      expect(config.resource_model).to eq(User)
    end
  end

  describe "#validate!" do
    it "levanta erro quando client_id é blank" do
      config.client_id = nil
      config.client_secret = "secret"
      expect { config.validate! }.to raise_error(KeycloakRails::ConfigurationError, /client_id/)
    end

    it "levanta erro quando client_secret é blank" do
      config.client_id = "client"
      config.client_secret = nil
      expect { config.validate! }.to raise_error(KeycloakRails::ConfigurationError, /client_secret/)
    end

    it "levanta erro quando server_url é blank" do
      config.server_url = ""
      config.client_id = "client"
      config.client_secret = "secret"
      expect { config.validate! }.to raise_error(KeycloakRails::ConfigurationError, /server_url/)
    end

    it "levanta erro quando realm é blank" do
      config.realm = ""
      config.client_id = "client"
      config.client_secret = "secret"
      expect { config.validate! }.to raise_error(KeycloakRails::ConfigurationError, /realm/)
    end

    it "não levanta erro quando tudo está configurado" do
      config.client_id = "client"
      config.client_secret = "secret"
      config.server_url = "http://keycloak.test"
      config.realm = "test"
      expect { config.validate! }.not_to raise_error
    end
  end
end
