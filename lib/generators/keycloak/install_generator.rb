# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Keycloak
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Instala o KeycloakRails criando o arquivo de inicialização"

      # Optional scope argument (e.g. "servidor", "cidadao").
      # Omit for the default single-scope setup.
      argument :scope, type: :string, default: "default",
               desc: "Nome do escopo de autenticação (ex: servidor, cidadao)"

      def copy_initializer
        if scope == "default"
          template "initializer.rb.tt", "config/initializers/keycloak_rails.rb"
        else
          template "initializer_scoped.rb.tt",
                   "config/initializers/keycloak_rails_#{scope}.rb"
        end
      end

      def show_instructions
        say ""
        say "=== KeycloakRails instalado com sucesso! (scope: #{scope}) ===", :green
        say ""

        if scope == "default"
          say "Configure as variáveis de ambiente:", :yellow
          say "  KEYCLOAK_SERVER_URL      - URL do servidor Keycloak"
          say "  KEYCLOAK_REALM           - Nome do realm"
          say "  KEYCLOAK_CLIENT_ID       - ID do client"
          say "  KEYCLOAK_CLIENT_SECRET   - Secret do client"
          say ""
          say "Agora execute o generator para configurar seu modelo:", :yellow
          say "  rails g keycloak Usuario"
        else
          prefix = scope.upcase
          say "Configure as variáveis de ambiente:", :yellow
          say "  KEYCLOAK_#{prefix}_SERVER_URL    - URL do servidor Keycloak"
          say "  KEYCLOAK_#{prefix}_REALM         - Nome do realm"
          say "  KEYCLOAK_#{prefix}_CLIENT_ID     - ID do client"
          say "  KEYCLOAK_#{prefix}_CLIENT_SECRET - Secret do client"
          say ""
          say "Agora execute o generator para configurar seu modelo:", :yellow
          say "  rails g keycloak ModelName #{scope}"
          say ""
          say "Monte o engine no seu config/routes.rb:", :yellow
          say "  mount KeycloakRails::Engine, at: \"/keycloak/#{scope}\","
          say "        as: \"keycloak_#{scope}\","
          say "        defaults: { keycloak_scope: \"#{scope}\" }"
          say ""
          say "No controller-base que usará este escopo:", :yellow
          say "  include KeycloakRails::Controllers::Concerns::Authentication"
          say "  def keycloak_scope = :#{scope}"
        end
        say ""
      end
    end
  end
end
