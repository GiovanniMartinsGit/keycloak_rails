# KeycloakRails

Gem para integração do **Keycloak** como sistema de autenticação em aplicações **Ruby on Rails monolíticas**, substituindo o Devise.

Funciona como **Rack Middleware**, gerenciando sessões via **OpenID Connect**, com verificação segura de tokens JWT (assinatura via JWKS) e controle de permissões por **Client Roles** do Keycloak.

Suporta **múltiplos escopos de autenticação** na mesma aplicação (ex.: servidores e cidadãos com Realms, clients e rotas completamente independentes), mantendo total compatibilidade retroativa com projetos de escopo único.

## Características

- **Substitui o Devise** — Autenticação completa via Keycloak (login, logout, sessões)
- **Múltiplos escopos independentes** — Dois ou mais domínios de autenticação na mesma app, sem interferência entre si
- **Rack Middleware** — Gerenciamento automático de sessão e renovação de tokens expirados
- **JWT com verificação de assinatura** — Tokens são validados criptograficamente via JWKS (RS256), com cache automático por Realm
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

---

## Modo 1 — Escopo único (padrão / legado)

Use este modo quando a aplicação possui apenas um domínio de autenticação (ex.: somente servidores, ou somente cidadãos). É totalmente compatível com versões anteriores da gem.

### 1. Instalar o inicializador

```bash
rails g keycloak:install
```

Cria `config/initializers/keycloak_rails.rb`.

### 2. Configurar o modelo de usuário

```bash
rails g keycloak Usuario
```

Cria a migration de `keycloak_id`, injeta o concern no modelo e atualiza o inicializador. Em seguida:

```bash
rails db:migrate
```

### 3. Variáveis de ambiente

```bash
KEYCLOAK_SERVER_URL="https://sso.seudominio.com.br"
KEYCLOAK_REALM="MeuRealm"
KEYCLOAK_CLIENT_ID="minha-aplicacao"
KEYCLOAK_CLIENT_SECRET="seu-client-secret"
```

### 4. Inicializador

```ruby
# config/initializers/keycloak_rails.rb
KeycloakRails.configure do |config|
  config.server_url  = ENV.fetch("KEYCLOAK_SERVER_URL")
  config.realm       = ENV.fetch("KEYCLOAK_REALM")
  config.client_id   = ENV.fetch("KEYCLOAK_CLIENT_ID")
  config.client_secret = ENV.fetch("KEYCLOAK_CLIENT_SECRET")

  config.resource_model_class_name = "Usuario"
  config.permission_name           = "access_minha_aplicacao"

  config.skip_paths = [%r{\A/assets}, %r{\A/paginas_publicas}]

  config.create_user_on_first_login = false
  config.after_sign_in_path  = "/"
  config.after_sign_out_path = "/"

  config.permission_denied_path   = "/401"
  config.permission_denied_status = :unauthorized

  config.ssl_verify = true
  # config.ca_file = "/caminho/para/ca-bundle.crt"
end
```

> A engine é montada automaticamente em `/keycloak` pelo initializer da gem.

### 5. Proteger controllers

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_keycloak_user!
end

class PaginasPublicasController < ApplicationController
  skip_before_action :authenticate_keycloak_user!
end
```

---

## Modo 2 — Múltiplos escopos de autenticação

Use este modo quando a aplicação precisa de **dois ou mais domínios de autenticação independentes** (ex.: servidores internos + cidadãos via GOV.br). Cada escopo tem seu próprio Realm, client, modelo de usuário, rotas e sessão isolada.

### 1. Instalar os inicializadores

```bash
rails g keycloak:install servidor
rails g keycloak:install cidadao
```

Cria `config/initializers/keycloak_rails_servidor.rb` e `keycloak_rails_cidadao.rb`.

### 2. Configurar os modelos de usuário

```bash
rails g keycloak Servidor servidor
rails g keycloak Cidadao cidadao
```

Cria as migrations e injeta o concern em cada modelo. Em seguida:

```bash
rails db:migrate
```

### 3. Variáveis de ambiente

```bash
# Escopo servidor
KEYCLOAK_SERVIDOR_SERVER_URL="https://sso.seudominio.com.br"
KEYCLOAK_SERVIDOR_REALM="servidores"
KEYCLOAK_SERVIDOR_CLIENT_ID="app-servidor"
KEYCLOAK_SERVIDOR_CLIENT_SECRET="secret-servidor"

# Escopo cidadão
KEYCLOAK_CIDADAO_SERVER_URL="https://sso.acesso.gov.br"
KEYCLOAK_CIDADAO_REALM="cidadaos"
KEYCLOAK_CIDADAO_CLIENT_ID="app-cidadao"
KEYCLOAK_CIDADAO_CLIENT_SECRET="secret-cidadao"
```

### 4. Inicializadores

```ruby
# config/initializers/keycloak_rails_servidor.rb
KeycloakRails.configure(:servidor) do |config|
  config.server_url    = ENV.fetch("KEYCLOAK_SERVIDOR_SERVER_URL")
  config.realm         = ENV.fetch("KEYCLOAK_SERVIDOR_REALM")
  config.client_id     = ENV.fetch("KEYCLOAK_SERVIDOR_CLIENT_ID")
  config.client_secret = ENV.fetch("KEYCLOAK_SERVIDOR_CLIENT_SECRET")

  config.resource_model_class_name = "Servidor"
  config.permission_name           = "acesso_sistema"  # role obrigatória

  config.skip_paths          = [%r{\A/assets}]
  config.after_sign_in_path  = "/admin"
  config.after_sign_out_path = "/admin/login"

  config.permission_denied_path   = "/403"
  config.permission_denied_status = :forbidden
end

# config/initializers/keycloak_rails_cidadao.rb
KeycloakRails.configure(:cidadao) do |config|
  config.server_url    = ENV.fetch("KEYCLOAK_CIDADAO_SERVER_URL")
  config.realm         = ENV.fetch("KEYCLOAK_CIDADAO_REALM")
  config.client_id     = ENV.fetch("KEYCLOAK_CIDADAO_CLIENT_ID")
  config.client_secret = ENV.fetch("KEYCLOAK_CIDADAO_CLIENT_SECRET")

  config.resource_model_class_name = "Cidadao"
  config.permission_name           = nil  # cidadão não precisa de role específica

  config.skip_paths          = [%r{\A/assets}, %r{\A/portal/publico}]
  config.after_sign_in_path  = "/portal"
  config.after_sign_out_path = "/portal"

  # Hint para o Keycloak redirecionar direto para o GOV.br
  # config.idp_hint = "govbr"
end
```

### 5. Rotas

Escopos nomeados **devem** ser montados manualmente. A engine **não** é montada automaticamente quando há escopos nomeados.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount KeycloakRails::Engine,
        at:       "/keycloak/servidor",
        as:       "keycloak_servidor",
        defaults: { keycloak_scope: "servidor" }

  mount KeycloakRails::Engine,
        at:       "/keycloak/cidadao",
        as:       "keycloak_cidadao",
        defaults: { keycloak_scope: "cidadao" }

  # suas rotas normais...
end
```

Isso expõe:

| Rota                               | Escopo   |
| ---------------------------------- | -------- |
| `GET  /keycloak/servidor/login`    | Servidor |
| `GET  /keycloak/servidor/callback` | Servidor |
| `DELETE /keycloak/servidor/logout` | Servidor |
| `GET  /keycloak/cidadao/login`     | Cidadão  |
| `GET  /keycloak/cidadao/callback`  | Cidadão  |
| `DELETE /keycloak/cidadao/logout`  | Cidadão  |

### 6. Controllers

Defina `keycloak_scope` no controller base de cada área:

```ruby
# app/controllers/admin/base_controller.rb
class Admin::BaseController < ApplicationController
  def keycloak_scope = :servidor
  before_action :authenticate_keycloak_user!
end

# app/controllers/portal/base_controller.rb
class Portal::BaseController < ApplicationController
  def keycloak_scope = :cidadao
  # before_action opcional — cidadãos podem ter páginas públicas
end

# app/controllers/portal/area_restrita_controller.rb
class Portal::AreaRestritaController < Portal::BaseController
  before_action :authenticate_keycloak_user!
end
```

### 7. Views

Use os helpers com o escopo correto:

```erb
<%# Área do servidor %>
<% if keycloak_user_signed_in? %>
  Olá, <%= current_user.nome %>
  <%= keycloak_logout_button "Sair", scope: :servidor, class: "btn btn-outline-danger" %>
<% else %>
  <%= link_to "Entrar", keycloak_servidor.login_path %>
<% end %>

<%# Área do cidadão %>
<% if keycloak_user_signed_in? %>
  Olá, <%= current_user.nome %>
  <%= keycloak_logout_button "Sair", scope: :cidadao %>
<% else %>
  <%= link_to "Acessar com GOV.br", keycloak_cidadao.login_path %>
<% end %>
```

### Isolamento de sessão

As chaves de sessão são **completamente isoladas** por escopo. Um usuário autenticado como `:servidor` não interfere na sessão `:cidadao`:

| Campo       | Escopo `:default`          | Escopo `:servidor`                  | Escopo `:cidadao`                  |
| ----------- | -------------------------- | ----------------------------------- | ---------------------------------- |
| user_id     | `:_keycloak_user_id`       | `:_keycloak_servidor_user_id`       | `:_keycloak_cidadao_user_id`       |
| autenticado | `:_keycloak_authenticated` | `:_keycloak_servidor_authenticated` | `:_keycloak_cidadao_authenticated` |
| oauth_state | `:keycloak_oauth_state`    | `:_keycloak_servidor_oauth_state`   | `:_keycloak_cidadao_oauth_state`   |

---

## Uso

### Helpers disponíveis nos controllers e views

```ruby
current_user              # usuário autenticado no escopo atual
keycloak_user_signed_in?  # true/false
```

### Logout

Use o helper para gerar um botão compatível com Turbo/Hotwire:

```erb
<%= keycloak_logout_button "Sair" %>
<%= keycloak_logout_button "Sair", class: "btn btn-danger" %>
```

Ou manualmente (escopo único):

```erb
<%= button_to "Sair", keycloak_logout_path, method: :delete, data: { turbo: false } %>
```

Manualmente com escopo nomeado:

```erb
<%= button_to "Sair", keycloak_servidor.logout_path, method: :delete, data: { turbo: false } %>
```

### Logout programático em controllers

```ruby
class SeuController < ApplicationController
  def encerrar_sessao
    sign_out_keycloak_user!
  end
end
```

### Rotas (escopo único)

A engine é montada automaticamente em `/keycloak`:

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
