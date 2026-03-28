# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Services::TokenIntrospectionService do
  subject(:service) { described_class.new }

  describe "#call" do
    it "retorna dados da introspecção do token" do
      stub_introspect(active: true)

      result = service.call("test-access-token")

      expect(result["active"]).to be true
      expect(result["sub"]).to eq("keycloak-user-id-123")
    end

    it "envia parâmetros corretos" do
      stub = stub_request(:post, "#{keycloak_base_url}/token/introspect")
        .with(body: {
          "token" => "test-token",
          "client_id" => "test-client",
          "client_secret" => "test-secret"
        })
        .to_return(status: 200, body: { "active" => true }.to_json, headers: { "Content-Type" => "application/json" })

      service.call("test-token")
      expect(stub).to have_been_requested
    end
  end

  describe "#active?" do
    context "quando token está ativo" do
      it "retorna true" do
        stub_introspect(active: true)
        expect(service.active?("test-token")).to be true
      end
    end

    context "quando token está inativo" do
      it "retorna false" do
        stub_introspect(active: false)
        expect(service.active?("test-token")).to be false
      end
    end

    context "quando ocorre erro HTTP" do
      it "retorna false" do
        stub_request(:post, "#{keycloak_base_url}/token/introspect")
          .to_return(status: 500, body: "Internal Error")

        expect(service.active?("test-token")).to be false
      end
    end
  end
end
