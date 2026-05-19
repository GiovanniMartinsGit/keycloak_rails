# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Helpers::ViewHelper do
  let(:default_routes) do
    double("default_routes", login_path: "/keycloak/login", logout_path: "/keycloak/logout")
  end

  let(:servidor_routes) do
    double("servidor_routes", login_path: "/keycloak/servidor/login", logout_path: "/keycloak/servidor/logout")
  end

  let(:helper_context_class) do
    Class.new do
      include KeycloakRails::Helpers::ViewHelper

      attr_writer :default_routes, :servidor_routes

      def keycloak_scope
        :servidor
      end

      def keycloak_rails
        @default_routes
      end

      def keycloak_servidor
        @servidor_routes
      end

      def button_to(text, path, **options)
        { text: text, path: path, options: options }
      end
    end
  end

  let(:helper_context) do
    helper_context_class.new.tap do |context|
      context.default_routes = default_routes
      context.servidor_routes = servidor_routes
    end
  end

  describe "#keycloak_logout_path" do
    it "usa a rota do escopo atual quando houver escopo nomeado" do
      expect(helper_context.keycloak_logout_path).to eq("/keycloak/servidor/logout")
    end
  end

  describe "#keycloak_logout_button" do
    it "gera o botao apontando para a rota do escopo atual" do
      button = helper_context.keycloak_logout_button("Sair")

      expect(button[:path]).to eq("/keycloak/servidor/logout")
      expect(button[:options][:method]).to eq(:delete)
      expect(button[:options][:data]).to eq({ turbo: false })
    end
  end
end