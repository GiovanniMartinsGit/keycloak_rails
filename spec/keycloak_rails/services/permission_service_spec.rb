# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Services::PermissionService do
  subject(:service) { described_class.new }

  let(:token_service) { instance_double(KeycloakRails::Services::TokenService) }

  before do
    allow(KeycloakRails::Services::TokenService).to receive(:new).and_return(token_service)
  end

  describe "#user_has_permission?" do
    context "quando o token contém a client role exigida" do
      it "retorna true" do
        decoded_token = {
          "resource_access" => {
            "test-client" => { "roles" => ["access_role", "admin"] }
          }
        }
        allow(token_service).to receive(:decode_token).and_return(decoded_token)

        KeycloakRails.configuration.permission_name = "access_role"

        expect(service.user_has_permission?("test-token")).to be true
      end
    end

    context "quando o token NÃO contém a client role exigida" do
      it "retorna false" do
        decoded_token = {
          "resource_access" => {
            "test-client" => { "roles" => ["other_role"] }
          }
        }
        allow(token_service).to receive(:decode_token).and_return(decoded_token)

        KeycloakRails.configuration.permission_name = "access_role"

        expect(service.user_has_permission?("test-token")).to be false
      end
    end

    context "quando o token não possui resource_access para o client" do
      it "retorna false" do
        decoded_token = {
          "resource_access" => {
            "outro-client" => { "roles" => ["access_role"] }
          }
        }
        allow(token_service).to receive(:decode_token).and_return(decoded_token)

        KeycloakRails.configuration.permission_name = "access_role"

        expect(service.user_has_permission?("test-token")).to be false
      end
    end

    context "quando o token não possui resource_access" do
      it "retorna false" do
        decoded_token = { "sub" => "user-id" }
        allow(token_service).to receive(:decode_token).and_return(decoded_token)

        KeycloakRails.configuration.permission_name = "access_role"

        expect(service.user_has_permission?("test-token")).to be false
      end
    end

    context "quando permission_name é nil" do
      it "retorna true sem decodificar o token" do
        KeycloakRails.configuration.permission_name = nil

        expect(token_service).not_to receive(:decode_token)
        expect(service.user_has_permission?("test-token")).to be true
      end
    end

    context "quando permission_name é passado como argumento" do
      it "usa o argumento em vez da configuração" do
        decoded_token = {
          "resource_access" => {
            "test-client" => { "roles" => ["custom_permission"] }
          }
        }
        allow(token_service).to receive(:decode_token).and_return(decoded_token)

        KeycloakRails.configuration.permission_name = "access_role"

        expect(service.user_has_permission?("test-token", "custom_permission")).to be true
      end
    end

    context "quando decode_token levanta erro" do
      it "retorna false" do
        allow(token_service).to receive(:decode_token)
          .and_raise(KeycloakRails::TokenInvalidError, "Token inválido")

        KeycloakRails.configuration.permission_name = "access_role"

        expect(service.user_has_permission?("test-token")).to be false
      end
    end
  end

  describe "#user_roles" do
    it "retorna client roles e realm roles" do
      decoded_token = {
        "resource_access" => {
          "test-client" => { "roles" => ["access_role", "admin"] }
        },
        "realm_access" => {
          "roles" => ["offline_access", "uma_authorization"]
        }
      }
      allow(token_service).to receive(:decode_token).and_return(decoded_token)

      roles = service.user_roles("test-token")

      expect(roles[:client_roles]).to eq(["access_role", "admin"])
      expect(roles[:realm_roles]).to eq(["offline_access", "uma_authorization"])
    end

    it "retorna arrays vazios quando não há roles" do
      decoded_token = { "sub" => "user-id" }
      allow(token_service).to receive(:decode_token).and_return(decoded_token)

      roles = service.user_roles("test-token")

      expect(roles[:client_roles]).to eq([])
      expect(roles[:realm_roles]).to eq([])
    end
  end
end
