# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Http::Client do
  subject(:client) { described_class.new(base_url: "http://keycloak.test") }

  describe "#get" do
    it "retorna o body da resposta para status 200" do
      stub_request(:get, "http://keycloak.test/test")
        .to_return(status: 200, body: { "key" => "value" }.to_json, headers: { "Content-Type" => "application/json" })

      result = client.get("http://keycloak.test/test")
      expect(result).to eq({ "key" => "value" })
    end

    it "levanta AuthenticationError para status 401" do
      stub_request(:get, "http://keycloak.test/test")
        .to_return(status: 401, body: "Unauthorized")

      expect { client.get("http://keycloak.test/test") }
        .to raise_error(KeycloakRails::AuthenticationError)
    end

    it "levanta PermissionDeniedError para status 403" do
      stub_request(:get, "http://keycloak.test/test")
        .to_return(status: 403, body: "Forbidden")

      expect { client.get("http://keycloak.test/test") }
        .to raise_error(KeycloakRails::PermissionDeniedError)
    end

    it "levanta HttpError para outros status de erro" do
      stub_request(:get, "http://keycloak.test/test")
        .to_return(status: 500, body: "Internal Server Error")

      expect { client.get("http://keycloak.test/test") }
        .to raise_error(KeycloakRails::HttpError) do |error|
          expect(error.status).to eq(500)
        end
    end
  end

  describe "#post" do
    it "envia dados e retorna o body da resposta" do
      stub_request(:post, "http://keycloak.test/test")
        .with(body: { "param" => "value" })
        .to_return(status: 200, body: { "result" => "ok" }.to_json, headers: { "Content-Type" => "application/json" })

      result = client.post("http://keycloak.test/test", body: { "param" => "value" })
      expect(result).to eq({ "result" => "ok" })
    end

    it "envia headers customizados" do
      stub_request(:post, "http://keycloak.test/test")
        .with(headers: { "Authorization" => "Bearer token123" })
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect { client.post("http://keycloak.test/test", headers: { "Authorization" => "Bearer token123" }) }
        .not_to raise_error
    end
  end
end
