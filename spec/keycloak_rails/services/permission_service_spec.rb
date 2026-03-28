# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Services::PermissionService do
  subject(:service) { described_class.new }

  describe "#user_has_permission?" do
    context "quando permissão é concedida" do
      it "retorna true" do
        stub_request(:post, "#{keycloak_base_url}/token")
          .with(body: hash_including(
            "grant_type" => "urn:ietf:params:oauth:grant-type:uma-ticket",
            "audience" => "test-client",
            "permission" => "access_transparencia",
            "response_mode" => "decision"
          ))
          .to_return(status: 200, body: { "result" => true }.to_json, headers: { "Content-Type" => "application/json" })

        expect(service.user_has_permission?("test-token", "access_transparencia")).to be true
      end
    end

    context "quando permissão é negada" do
      it "retorna false" do
        stub_request(:post, "#{keycloak_base_url}/token")
          .to_return(status: 403, body: { "error" => "access_denied" }.to_json, headers: { "Content-Type" => "application/json" })

        expect(service.user_has_permission?("test-token", "access_transparencia")).to be false
      end
    end

    context "quando token é inválido" do
      it "retorna false" do
        stub_request(:post, "#{keycloak_base_url}/token")
          .to_return(status: 401, body: "Unauthorized")

        expect(service.user_has_permission?("invalid-token", "access_transparencia")).to be false
      end
    end

    context "quando permission_name é nil" do
      it "retorna true sem chamar o Keycloak" do
        KeycloakRails.configuration.permission_name = nil
        expect(service.user_has_permission?("test-token")).to be true
      end
    end

    context "quando usa permission_name da configuração" do
      it "usa o valor configurado" do
        KeycloakRails.configuration.permission_name = "access_sistema"

        stub = stub_request(:post, "#{keycloak_base_url}/token")
          .with(body: hash_including("permission" => "access_sistema"))
          .to_return(status: 200, body: { "result" => true }.to_json, headers: { "Content-Type" => "application/json" })

        service.user_has_permission?("test-token")
        expect(stub).to have_been_requested
      end
    end
  end
end
