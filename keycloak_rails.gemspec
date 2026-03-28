# frozen_string_literal: true

require_relative "lib/keycloak_rails/version"

Gem::Specification.new do |spec|
  spec.name          = "keycloak_rails"
  spec.version       = KeycloakRails::VERSION
  spec.authors       = ["GM Dev"]
  spec.email         = ["dev@prefeitura.gov.br"]

  spec.summary       = "Integração Keycloak para aplicações Rails monolíticas"
  spec.description   = "Gem para autenticação e autorização via Keycloak em aplicações Rails monolíticas, substituindo o Devise. Funciona como Rack Middleware com suporte a permissões por client."
  spec.homepage      = "https://github.com/prefeitura/keycloak_rails"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "jwt", "~> 2.7"

  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "factory_bot_rails", "~> 6.2"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-rails", "~> 2.19"
  spec.add_development_dependency "rubocop-rspec", "~> 2.22"
end
