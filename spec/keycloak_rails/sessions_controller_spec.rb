# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::SessionsController do
  subject(:controller) { described_class.new }

  let(:flash_hash) { {} }
  let(:main_app) { instance_double("MainAppRoutes", root_path: "/", billing_path: "/billing") }

  before do
    allow(controller).to receive(:flash).and_return(flash_hash)
    allow(controller).to receive(:redirect_to)
    allow(controller).to receive(:main_app).and_return(main_app)
  end

  describe "#resolve_permission_denied_path" do
    it "retorna a string configurada" do
      KeycloakRails.configuration.permission_denied_path = "/assinatura"

      expect(controller.send(:resolve_permission_denied_path)).to eq("/assinatura")
    end

    it "resolve helper de rota quando configurado com symbol" do
      KeycloakRails.configuration.permission_denied_path = :billing_path

      expect(controller.send(:resolve_permission_denied_path)).to eq("/billing")
    end

    it "executa proc quando configurado" do
      KeycloakRails.configuration.permission_denied_path = -> { main_app.billing_path }

      expect(controller.send(:resolve_permission_denied_path)).to eq("/billing")
    end

    it "levanta erro quando helper de rota não existe" do
      KeycloakRails.configuration.permission_denied_path = :rota_inexistente

      expect { controller.send(:resolve_permission_denied_path) }
        .to raise_error(KeycloakRails::ConfigurationError, /permission_denied_path/)
    end
  end

  describe "#handle_permission_error" do
    it "redireciona para a rota configurada com flash de alerta" do
      KeycloakRails.configuration.permission_denied_path = "/assinatura"

      expect(controller).to receive(:redirect_to).with("/assinatura")

      controller.send(:handle_permission_error, KeycloakRails::PermissionDeniedError.new("sem acesso"))

      expect(flash_hash[:alert]).to include("não possui permissão")
    end
  end
end
