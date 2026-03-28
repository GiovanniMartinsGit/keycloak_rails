# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Services::UserResolverService do
  subject(:service) { described_class.new }

  let(:user_info) do
    {
      "sub" => "keycloak-user-id-123",
      "email" => "usuario@teste.com",
      "name" => "Usuário Teste",
      "preferred_username" => "usuario.teste"
    }
  end

  describe "#call" do
    context "quando usuário existe pelo email" do
      let!(:user) { User.create!(email: "usuario@teste.com", nome: "Usuário Existente") }

      it "retorna o usuário encontrado" do
        result = service.call(user_info)
        expect(result).to eq(user)
      end

      it "atualiza o keycloak_id do usuário" do
        service.call(user_info)
        user.reload
        expect(user.keycloak_id).to eq("keycloak-user-id-123")
      end

      it "não atualiza keycloak_id se já está correto" do
        user.update!(keycloak_id: "keycloak-user-id-123")

        expect(user).not_to receive(:update!)
        allow(KeycloakRails.configuration.resource_model).to receive(:find_by).and_return(user)

        service.call(user_info)
      end
    end

    context "quando usuário não existe" do
      it "levanta UserNotFoundError" do
        expect { service.call(user_info) }
          .to raise_error(KeycloakRails::UserNotFoundError, /não encontrado na aplicação/)
      end

      context "e create_user_on_first_login está ativado" do
        before { KeycloakRails.configuration.create_user_on_first_login = true }

        it "cria o usuário automaticamente" do
          result = service.call(user_info)
          expect(result).to be_a(User)
          expect(result.email).to eq("usuario@teste.com")
          expect(result.keycloak_id).to eq("keycloak-user-id-123")
        end
      end
    end

    context "quando email está ausente" do
      it "levanta UserNotFoundError" do
        info = user_info.merge("email" => nil)
        expect { service.call(info) }
          .to raise_error(KeycloakRails::UserNotFoundError, /Email não encontrado/)
      end
    end

    context "quando sub está ausente" do
      it "levanta UserNotFoundError" do
        info = user_info.merge("sub" => nil)
        expect { service.call(info) }
          .to raise_error(KeycloakRails::UserNotFoundError, /Keycloak ID/)
      end
    end
  end
end
