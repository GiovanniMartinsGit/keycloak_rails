# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Services::UserInfoService do
  subject(:service) { described_class.new }

  describe "#call" do
    it "retorna informações do usuário" do
      stub_userinfo

      result = service.call("test-access-token")

      expect(result["sub"]).to eq("keycloak-user-id-123")
      expect(result["email"]).to eq("usuario@teste.com")
      expect(result["name"]).to eq("Usuário Teste")
    end

    it "envia o token de autorização no header" do
      stub = stub_request(:get, "#{keycloak_base_url}/userinfo")
        .with(headers: { "Authorization" => "Bearer my-token" })
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      service.call("my-token")
      expect(stub).to have_been_requested
    end

    it "levanta erro quando token é inválido" do
      stub_request(:get, "#{keycloak_base_url}/userinfo")
        .to_return(status: 401, body: "Unauthorized")

      expect { service.call("invalid-token") }
        .to raise_error(KeycloakRails::AuthenticationError)
    end
  end
end
