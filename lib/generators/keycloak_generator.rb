# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

class KeycloakGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path("keycloak/templates", __dir__)

  desc "Configura o modelo para autenticação via Keycloak, adicionando os campos email e keycloak_id"

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end

  def copy_create_migration
    migration_template "add_keycloak_fields.rb.tt",
                       "db/migrate/add_keycloak_fields_to_#{table_name}.rb"
  end

  def inject_concern_into_model
    model_file = "app/models/#{file_name}.rb"

    if File.exist?(model_file)
      inject_into_class model_file, class_name do
        "  include KeycloakRails::Models::Concerns::KeycloakAuthenticatable\n\n"
      end
      say_status :inject, "KeycloakAuthenticatable no modelo #{class_name}", :green
    else
      say_status :skip, "Arquivo #{model_file} não encontrado. Adicione manualmente:", :yellow
      say "  include KeycloakRails::Models::Concerns::KeycloakAuthenticatable"
    end
  end

  def update_initializer
    initializer_file = "config/initializers/keycloak_rails.rb"

    if File.exist?(initializer_file)
      gsub_file initializer_file,
                /config\.resource_model_class_name\s*=\s*".*"/,
                "config.resource_model_class_name = \"#{class_name}\""
      say_status :update, "Initializer atualizado com modelo #{class_name}", :green
    end
  end

  def show_instructions
    say ""
    say "=== Modelo #{class_name} configurado para KeycloakRails! ===", :green
    say ""
    say "Execute a migration:", :yellow
    say "  rails db:migrate"
    say ""
    say "Certifique-se de que o modelo #{class_name} possui os campos:", :yellow
    say "  - email (string, obrigatório, único)"
    say "  - keycloak_id (string, único)"
    say ""
  end

  private

  def table_name
    class_name.tableize
  end
end
