# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Keycloak
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Instala o KeycloakRails criando o arquivo de inicialização"

      def copy_initializer
        template "initializer.rb.tt", "config/initializers/keycloak_rails.rb"
      end

      def show_instructions
        say ""
        say "=== KeycloakRails instalado com sucesso! ===", :green
        say ""
        say "Configure as variáveis de ambiente:", :yellow
        say "  KEYCLOAK_SERVER_URL  - URL do servidor Keycloak"
        say "  KEYCLOAK_REALM       - Nome do realm"
        say "  KEYCLOAK_CLIENT_ID   - ID do client"
        say "  KEYCLOAK_CLIENT_SECRET - Secret do client"
        say ""
        say "Agora execute o generator para configurar seu modelo:", :yellow
        say "  rails g keycloak Usuario"
        say ""
      end
    end
  end
end
