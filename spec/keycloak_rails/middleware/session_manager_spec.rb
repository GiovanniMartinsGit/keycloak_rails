# frozen_string_literal: true

require "spec_helper"
require "rack/test"

RSpec.describe KeycloakRails::Middleware::SessionManager do
  include Rack::Test::Methods

  let(:inner_app) do
    lambda { |env|
      [200, { "Content-Type" => "text/plain" }, ["OK - authenticated: #{env['keycloak_rails.authenticated']}"]]
    }
  end

  let(:app) do
    session_app = inner_app
    Rack::Builder.new do
      use Rack::Session::Cookie, secret: "test-secret-key-for-session-12345"
      use KeycloakRails::Middleware::SessionManager
      run session_app
    end
  end

  describe "requisição sem sessão" do
    it "define authenticated como false" do
      get "/"
      expect(last_response.body).to include("authenticated: false")
    end
  end

  describe "requisição com sessão válida" do
    it "define authenticated como true para token não expirado" do
      token = generate_test_jwt(exp: (Time.now + 3600).to_i)

      env "rack.session", {
        "keycloak_rails" => {
          "access_token" => token,
          "refresh_token" => "test-refresh",
          "user_id" => 1,
          "expires_at" => (Time.now + 3600).to_i
        }
      }

      get "/"
      expect(last_response.body).to include("authenticated: true")
    end
  end

  describe "skip_paths" do
    before do
      KeycloakRails.configuration.skip_paths = [%r{\A/keycloak}, %r{\A/assets}]
    end

    it "não processa paths configurados para skip" do
      get "/keycloak/callback"
      expect(last_response.status).to eq(200)
    end

    it "não processa assets" do
      get "/assets/application.js"
      expect(last_response.status).to eq(200)
    end
  end

  describe "requisição com token expirado" do
    it "tenta renovar o token" do
      expired_token = generate_test_jwt(exp: (Time.now - 60).to_i)
      new_token = generate_test_jwt(exp: (Time.now + 3600).to_i)

      stub_request(:post, "#{keycloak_base_url}/token")
        .to_return(
          status: 200,
          body: {
            "access_token" => new_token,
            "refresh_token" => "new-refresh",
            "id_token" => "new-id-token",
            "expires_in" => 300
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      env "rack.session", {
        "keycloak_rails" => {
          "access_token" => expired_token,
          "refresh_token" => "old-refresh",
          "user_id" => 1,
          "expires_at" => (Time.now - 60).to_i
        }
      }

      get "/"
      expect(last_response.body).to include("authenticated: true")
    end

    it "limpa sessão quando refresh falha" do
      expired_token = generate_test_jwt(exp: (Time.now - 60).to_i)

      stub_request(:post, "#{keycloak_base_url}/token")
        .to_return(status: 401, body: "Invalid refresh token")

      env "rack.session", {
        "keycloak_rails" => {
          "access_token" => expired_token,
          "refresh_token" => "invalid-refresh",
          "user_id" => 1,
          "expires_at" => (Time.now - 60).to_i
        }
      }

      get "/"
      expect(last_response.body).to include("authenticated: false")
    end
  end
end
