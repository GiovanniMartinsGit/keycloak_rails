# KeycloakRails

Gem para integração do **Keycloak** como sistema de autenticação em aplicações **Ruby on Rails monolíticas**, substituindo o Devise.

Funciona como **Rack Middleware**, gerenciando sessões via **OpenID Connect**, com verificação segura de tokens JWT (assinatura via JWKS) e controle de permissões por **Client Roles** do Keycloak.

## Características

- **Substitui o Devise** — Autenticação completa via Keycloak (login, logout, sessões)
- **Rack Middleware** — Gerenciamento automático de sessão e renovação de tokens expirados
- **JWT com verificação de assinatura** — Tokens são validados criptograficamente via JWKS (RS256), com cache automático
- **Permissões por Client Roles** — Verifica se o usuário possui a role necessária no client do Keycloak
- **Vínculo por Email** — Identifica o usuário na aplicação pelo email e sincroniza o `keycloak_id` automaticamente
- **Revogação de sessão** — Logout revoga a sessão no Keycloak via refresh token (backchannel)
- **Compatível com Turbo/Hotwire** — Tratamento automático de redirects cross-origin em requests Turbo
- **Compatível com CanCanCan** — Autorização a nível de aplicação continua independente
- **Generators Rails** — Configuração rápida via `rails generate`
- **Proteção contra Open Redirect** — Validação de paths de redirecionamento pós-login
- **Sem vazamento de dados sensíveis** — Tokens e credenciais nunca são expostos em logs

## Requisitos

- Ruby >= 3.0.0
- Rails >= 7.0
- Keycloak Server configurado com:
  - Um **Realm**
  - Um **Client** do tipo `confidential` (com client_secret)
  - **Client Roles** atribuídas aos usuários que devem ter acesso

## Instalação

Adicione ao `Gemfile` da sua aplicação:

```ruby
gem "keycloak_rails", path: "caminho/para/keycloak_rails"
# ou, quando publicada:
# gem "keycloak_rails", "~> 1.0"
```

Execute:

```bash
bundle install
```

## Configuração

### 1. Instalar o inicializador

```bash
rails g keycloak:install
```

Cria o arquivo `config/initializers/keycloak_rails.rb` com todas as opções documentadas.

### 2. Configurar o modelo de usuário

```bash
rails g keycloak Usuario
```

Este comando:

- Cria uma migration para adicionar `keycloak_id` ao modelo `Usuario`
- Injeta o concern `KeycloakAuthenticatable` no modelo
- Atualiza o inicializador com o nome do modelo

Execute a migration:

```bash
rails db:migrate
```

### 3. Configurar variáveis de ambiente

```bash
export KEYCLOAK_SERVER_URL="https://sso.seudominio.com.br"
export KEYCLOAK_REALM="MeuRealm"
export KEYCLOAK_CLIENT_ID="minha-aplicacao"
export KEYCLOAK_CLIENT_SECRET="seu-client-secret"
```

### 4. Configurar o inicializador

Edite `config/initializers/keycloak_rails.rb`:

```ruby
KeycloakRails.configure do |config|
  config.server_url = ENV.fetch("KEYCLOAK_SERVER_URL")
  config.realm = ENV.fetch("KEYCLOAK_REALM")
  config.client_id = ENV.fetch("KEYCLOAK_CLIENT_ID")
  config.client_secret = ENV.fetch("KEYCLOAK_CLIENT_SECRET")

  # Modelo de usuário da aplicação
  config.resource_model_class_name = "Usuario"

  # Client Role exigida para acesso (configurada no Keycloak)
  # Deixe nil para não exigir role específica
  config.permission_name = "access_minha_aplicacao"

  # Caminhos que não exigem autenticação (além de /keycloak/* que é automático)
  config.skip_paths = [
    %r{\A/assets},
    %r{\A/paginas_publicas}
  ]

  # Criar usuário automaticamente no primeiro login via Keycloak?
  config.create_user_on_first_login = false

  # Caminhos de redirecionamento pós-login/logout
  config.after_sign_in_path = "/"
  config.after_sign_out_path = "/"

  # Retorno quando o usuário autentica, mas não tem a role exigida
  # Aceita String, Symbol (helper de rota) ou Proc
  # Ex.: "/401", :permission_denied_path, ->(env) { "/custom_path" }
  config.permission_denied_path = "/401"

  # HTTP status do retorno por falta de permissão de acesso(padrão: 401)
  config.permission_denied_status = :unauthorized

  # SSL (padrão: true). Não pode ser false em produção.
  config.ssl_verify = true
  # config.ca_file = "/caminho/para/ca-bundle.crt"  # Opcional
end
```

## Uso

### Proteger Controllers

Similar ao Devise, use `before_action` nos controllers:

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_keycloak_user!
end
```

Para controllers públicos:

```ruby
class PaginasPublicasController < ApplicationController
  skip_before_action :authenticate_keycloak_user!
end
```

### Helpers Disponíveis

Nos controllers e views:

```ruby
# Usuário atual (equivalente ao current_user do Devise)
current_user

# Verificar se está autenticado
keycloak_user_signed_in?
```

### Logout

O logout deve ser feito via `DELETE` (por segurança contra CSRF). Use o helper da gem:

```erb
<%= keycloak_logout_button "Sair" %>
```

O helper gera um `button_to` com `data-turbo: false` automaticamente, garantindo compatibilidade com Turbo/Hotwire.

Você também pode personalizar:

```erb
<%= keycloak_logout_button "Encerrar sessão", class: "btn btn-danger" %>
```

Ou construir manualmente:

```erb
<%= button_to "Sair", keycloak_logout_path, method: :delete, data: { turbo: false } %>
```

### Exemplo completo de layout

```erb
<nav>
  <% if keycloak_user_signed_in? %>
    <span>Olá, <%= current_user.nome %></span>
    <%= keycloak_logout_button "Sair", class: "btn btn-outline-danger" %>
  <% else %>
    <%= link_to "Entrar", keycloak_login_path, class: "btn btn-primary" %>
  <% end %>
</nav>
```

### Logout programático (em controllers)

```ruby
class SeuController < ApplicationController
  def encerrar_sessao
    sign_out_keycloak_user!
  end
end
```

### Rotas

A gem monta automaticamente as seguintes rotas em `/keycloak`:

| Rota                 | Método   | Descrição                                     |
| -------------------- | -------- | --------------------------------------------- |
| `/keycloak/login`    | `GET`    | Redireciona para o Keycloak para autenticação |
| `/keycloak/callback` | `GET`    | Callback OAuth2 (processamento do login)      |
| `/keycloak/logout`   | `DELETE` | Revoga sessão no Keycloak e faz logout local  |

### Modelo de Usuário

O modelo deve incluir o concern e ter os campos `email` e `keycloak_id`:

```ruby
class Usuario < ApplicationRecord
  include KeycloakRails::Models::Concerns::KeycloakAuthenticatable

  # Suas associações e validações existentes...
  # Pode continuar usando CanCanCan normalmente
end
```

O concern adiciona:

```ruby
# Validações
validates :email, presence: true, uniqueness: true
validates :keycloak_id, uniqueness: true, allow_nil: true

# Scopes
scope :with_keycloak    # Usuários vinculados ao Keycloak
scope :without_keycloak # Usuários não vinculados

# Métodos de instância
user.keycloak_linked?         # Verifica se está vinculado
user.link_keycloak!(sub)      # Vincula ao Keycloak
user.unlink_keycloak!         # Remove vínculo

# Métodos de classe
Usuario.find_by_keycloak_id(id)
Usuario.find_by_email_for_keycloak(email)
```

## Fluxo de Autenticação

```
Usuário acessa /pagina_protegida
         │
         ▼
┌─────────────────────┐
│ authenticate_keycloak│──── Autenticado? ──── SIM ──→ Acessa a página
│      _user!         │
└─────────────────────┘
         │ NÃO
         ▼
  Redirect → /keycloak/login
         │
         ▼
  Redirect → Keycloak SSO (tela de login)
         │
         ▼ (usuário faz login)
  Redirect → /keycloak/callback?code=xxx&state=xxx
         │
         ▼
┌─────────────────────┐
│  1. Valida state     │
│  2. Troca code →     │
│     tokens (JWT)     │
│  3. Valida assinatura│
│     JWT via JWKS     │
│  4. Busca user info  │
│  5. Verifica client  │
│     role             │
│  6. Resolve usuário  │
│     por email        │
│  7. Sincroniza       │
│     keycloak_id      │
│  8. Cria sessão      │
└─────────────────────┘
         │
         ▼
  Redirect → página original (ou /)
```

## Fluxo de Logout

```
Usuário clica "Sair" (DELETE /keycloak/logout)
         │
         ▼
┌─────────────────────┐
│  1. Recupera refresh │
│     token do store   │
│  2. POST ao Keycloak │
│     /logout com      │
│     refresh_token +  │
│     client_secret    │
│  3. Limpa token      │
│     store local      │
│  4. Limpa sessão     │
│     Rails            │
└─────────────────────┘
         │
         ▼
  Redirect → after_sign_out_path (/)
```

## Observações para Deploy

### Worker único (recomendado para simplicidade)

A gem armazena tokens em memória (Hash thread-safe). Em deploy com **Puma single-worker + threads**, funciona perfeitamente.

### Múltiplos workers

Em deploy com `WEB_CONCURRENCY > 1` (múltiplos workers Puma), cada worker tem seu próprio token store. Isso significa que:

- A **autenticação** (via `session[:_keycloak_user_id]`) funciona normalmente, pois a sessão está no cookie
- A **renovação automática de tokens expirados** pode não funcionar cross-worker

Para ambientes com múltiplos workers que precisam de renovação automática, considere usar Puma com `preload_app!` ou migrar o token store para um backend compartilhado (Redis, Memcached).
