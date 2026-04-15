# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_group "Services", "lib/keycloak_rails/services"
  add_group "Middleware", "lib/keycloak_rails/middleware"
  add_group "Controllers", "lib/keycloak_rails/controllers"
  add_group "Models", "lib/keycloak_rails/models"
end

require "bundler/setup"
require "active_record"
require "action_controller"
require "action_dispatch"
require "webmock/rspec"

# Configurar ActiveRecord em memória para testes
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :email
    t.string :keycloak_id
    t.string :nome
    t.timestamps
  end
end

require "keycloak_rails"

# Modelo de teste
class User < ActiveRecord::Base
  include KeycloakRails::Models::Concerns::KeycloakAuthenticatable
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random

  config.before(:each) do
    KeycloakRails.reset_configuration!
    KeycloakRails.configure do |c|
      c.server_url = "http://keycloak.test"
      c.realm = "test-realm"
      c.client_id = "test-client"
      c.client_secret = "test-secret"
      c.resource_model_class_name = "User"
      c.permission_name = nil
      c.logger = Logger.new(File::NULL)
    end
  end

  config.after(:each) do
    User.delete_all
  end
end

# Helpers
def keycloak_base_url
  "http://keycloak.test/realms/test-realm/protocol/openid-connect"
end

def stub_token_exchange(response_body = nil)
  body = response_body || {
    "access_token" => "test-access-token",
    "refresh_token" => "test-refresh-token",
    "id_token" => "test-id-token",
    "expires_in" => 300,
    "token_type" => "Bearer"
  }
  stub_request(:post, "#{keycloak_base_url}/token")
    .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
end

def stub_userinfo(response_body = nil)
  body = response_body || {
    "sub" => "keycloak-user-id-123",
    "email" => "usuario@teste.com",
    "name" => "Usuário Teste",
    "preferred_username" => "usuario.teste"
  }
  stub_request(:get, "#{keycloak_base_url}/userinfo")
    .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
end

def stub_introspect(active: true)
  body = { "active" => active, "sub" => "keycloak-user-id-123" }
  stub_request(:post, "#{keycloak_base_url}/token/introspect")
    .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
end

def stub_permission_check(granted: true)
  if granted
    stub_request(:post, "#{keycloak_base_url}/token")
      .with(body: hash_including("grant_type" => "urn:ietf:params:oauth:grant-type:uma-ticket"))
      .to_return(status: 200, body: { "result" => true }.to_json, headers: { "Content-Type" => "application/json" })
  else
    stub_request(:post, "#{keycloak_base_url}/token")
      .with(body: hash_including("grant_type" => "urn:ietf:params:oauth:grant-type:uma-ticket"))
      .to_return(status: 403, body: { "error" => "access_denied" }.to_json, headers: { "Content-Type" => "application/json" })
  end
end

def stub_jwks
  stub_request(:get, "#{keycloak_base_url}/certs")
    .to_return(status: 200, body: { "keys" => [] }.to_json, headers: { "Content-Type" => "application/json" })
end

def generate_test_jwt(payload = {}, exp: 1.hour.from_now.to_i)
  default_payload = {
    "sub" => "keycloak-user-id-123",
    "email" => "usuario@teste.com",
    "exp" => exp,
    "iss" => "http://keycloak.test/realms/test-realm",
    "aud" => "test-client"
  }
  JWT.encode(default_payload.merge(payload), nil, "none")
end
