# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Services::TokenService do
  subject(:service) { described_class.new }

  describe "#exchange_code" do
    it "troca authorization code por tokens" do
      stub_token_exchange

      result = service.exchange_code("auth-code-123", "http://app.test/callback")

      expect(result["access_token"]).to eq("test-access-token")
      expect(result["refresh_token"]).to eq("test-refresh-token")
      expect(result["id_token"]).to eq("test-id-token")
    end

    it "envia os parâmetros corretos" do
      stub = stub_request(:post, "#{keycloak_base_url}/token")
        .with(body: {
          "grant_type" => "authorization_code",
          "client_id" => "test-client",
          "client_secret" => "test-secret",
          "code" => "auth-code-123",
          "redirect_uri" => "http://app.test/callback"
        })
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      service.exchange_code("auth-code-123", "http://app.test/callback")
      expect(stub).to have_been_requested
    end

    it "levanta erro quando o Keycloak retorna erro" do
      stub_request(:post, "#{keycloak_base_url}/token")
        .to_return(status: 401, body: "Invalid code")

      expect { service.exchange_code("invalid-code", "http://app.test/callback") }
        .to raise_error(KeycloakRails::AuthenticationError)
    end
  end

  describe "#refresh_token" do
    it "renova o token usando refresh_token" do
      new_tokens = {
        "access_token" => "new-access-token",
        "refresh_token" => "new-refresh-token",
        "id_token" => "new-id-token",
        "expires_in" => 300
      }
      stub_token_exchange(new_tokens)

      result = service.refresh_token("old-refresh-token")
      expect(result["access_token"]).to eq("new-access-token")
    end
  end

  describe "#token_expired?" do
    it "retorna false para token não expirado" do
      token = generate_test_jwt(exp: (Time.now + 3600).to_i)
      expect(service.token_expired?(token)).to be false
    end

    it "retorna true para token expirado" do
      token = generate_test_jwt(exp: (Time.now - 60).to_i)
      expect(service.token_expired?(token)).to be true
    end

    it "retorna true para token prestes a expirar (dentro da tolerância)" do
      token = generate_test_jwt(exp: (Time.now + 5).to_i)
      expect(service.token_expired?(token)).to be true
    end

    it "retorna true para token inválido" do
      expect(service.token_expired?("invalid-token")).to be true
    end
  end
end
