# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Models::Concerns::KeycloakAuthenticatable do
  describe "validações" do
    it "exige email" do
      user = User.new(email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "exige email único" do
      User.create!(email: "usuario@teste.com")
      duplicate = User.new(email: "usuario@teste.com")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include("has already been taken")
    end

    it "exige keycloak_id único quando presente" do
      User.create!(email: "user1@teste.com", keycloak_id: "kc-id-1")
      duplicate = User.new(email: "user2@teste.com", keycloak_id: "kc-id-1")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:keycloak_id]).to include("has already been taken")
    end

    it "permite keycloak_id nil" do
      user = User.new(email: "usuario@teste.com", keycloak_id: nil)
      expect(user).to be_valid
    end
  end

  describe "scopes" do
    let!(:linked_user) { User.create!(email: "linked@teste.com", keycloak_id: "kc-123") }
    let!(:unlinked_user) { User.create!(email: "unlinked@teste.com", keycloak_id: nil) }

    it "with_keycloak retorna usuários vinculados" do
      expect(User.with_keycloak).to include(linked_user)
      expect(User.with_keycloak).not_to include(unlinked_user)
    end

    it "without_keycloak retorna usuários não vinculados" do
      expect(User.without_keycloak).to include(unlinked_user)
      expect(User.without_keycloak).not_to include(linked_user)
    end
  end

  describe "#keycloak_linked?" do
    it "retorna true quando keycloak_id está presente" do
      user = User.new(email: "user@teste.com", keycloak_id: "kc-123")
      expect(user.keycloak_linked?).to be true
    end

    it "retorna false quando keycloak_id está ausente" do
      user = User.new(email: "user@teste.com", keycloak_id: nil)
      expect(user.keycloak_linked?).to be false
    end
  end

  describe "#link_keycloak!" do
    it "vincula o keycloak_id ao usuário" do
      user = User.create!(email: "user@teste.com")
      user.link_keycloak!("kc-new-id")
      expect(user.reload.keycloak_id).to eq("kc-new-id")
    end
  end

  describe "#unlink_keycloak!" do
    it "remove o keycloak_id do usuário" do
      user = User.create!(email: "user@teste.com", keycloak_id: "kc-123")
      user.unlink_keycloak!
      expect(user.reload.keycloak_id).to be_nil
    end
  end

  describe ".find_by_keycloak_id" do
    it "encontra usuário pelo keycloak_id" do
      user = User.create!(email: "user@teste.com", keycloak_id: "kc-123")
      expect(User.find_by_keycloak_id("kc-123")).to eq(user)
    end

    it "retorna nil quando não encontrado" do
      expect(User.find_by_keycloak_id("inexistente")).to be_nil
    end
  end

  describe ".find_by_email_for_keycloak" do
    it "encontra usuário pelo email" do
      user = User.create!(email: "user@teste.com")
      expect(User.find_by_email_for_keycloak("user@teste.com")).to eq(user)
    end
  end
end
