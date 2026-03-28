# frozen_string_literal: true

require "spec_helper"

RSpec.describe KeycloakRails::Controllers::Concerns::Authentication do
  let(:controller_class) do
    Class.new do
      include KeycloakRails::Controllers::Concerns::Authentication

      attr_accessor :session, :request

      def initialize
        @session = {}
        @request = OpenStruct.new(fullpath: "/current-page", get?: true)
      end

      def redirect_to(*args); end
      def root_url; "http://app.test/"; end

      def self.helper_method(*args); end
      def self.respond_to?(method)
        method == :helper_method ? true : super
      end
    end
  end

  let(:controller) { controller_class.new }

  describe "#current_user" do
    it "retorna nil quando não há sessão" do
      expect(controller.current_user).to be_nil
    end

    it "retorna o usuário da sessão" do
      user = User.create!(email: "user@teste.com")
      controller.session[:_keycloak_user_id] = user.id

      expect(controller.current_user).to eq(user)
    end

    it "retorna nil quando usuário não existe mais" do
      controller.session[:_keycloak_user_id] = 99999

      expect(controller.current_user).to be_nil
    end

    it "memoiza o resultado" do
      user = User.create!(email: "user@teste.com")
      controller.session[:_keycloak_user_id] = user.id

      controller.current_user
      expect(User).not_to receive(:find_by)
      controller.current_user
    end
  end

  describe "#keycloak_user_signed_in?" do
    it "retorna false quando não há usuário" do
      expect(controller.keycloak_user_signed_in?).to be false
    end

    it "retorna true quando há usuário" do
      user = User.create!(email: "user@teste.com")
      controller.session[:_keycloak_user_id] = user.id

      expect(controller.keycloak_user_signed_in?).to be true
    end
  end

  describe "#authenticate_keycloak_user!" do
    it "não redireciona se usuário está autenticado" do
      user = User.create!(email: "user@teste.com")
      controller.session[:_keycloak_user_id] = user.id

      expect(controller).not_to receive(:redirect_to)
      controller.authenticate_keycloak_user!
    end

    it "redireciona para login se usuário não está autenticado" do
      expect(controller).to receive(:redirect_to)
      controller.authenticate_keycloak_user!
    end

    it "armazena a URL atual para redirecionamento pós-login" do
      allow(controller).to receive(:redirect_to)
      controller.authenticate_keycloak_user!
      expect(controller.session[:keycloak_rails_return_to]).to eq("/current-page")
    end
  end
end
