# KeycloakRails

Gem para autenticar aplicacoes Rails com Keycloak (OIDC), com suporte a escopo unico e multiplos escopos.

## Resumo rapido

- Login e logout via Keycloak
- Validacao de JWT com JWKS
- Renovacao de token via refresh token
- Verificacao opcional de permissao (client role)
- Isolamento de sessao por escopo

## Requisitos

- Ruby 3.0+
- Rails 7+
- Keycloak com client confidential (client secret)

## Instalacao

No Gemfile da aplicacao:

```ruby
gem "keycloak_rails", path: "caminho/para/keycloak_rails"
# ou, quando publicada
# gem "keycloak_rails"
```

Depois:

```bash
bundle install
```

## Guia 1: Escopo unico (default)

Use quando existe apenas um dominio de autenticacao.

### 1. Gerar initializer

```bash
rails g keycloak:install
```

### 2. Configurar modelo

```bash
rails g keycloak Usuario
rails db:migrate
```

### 3. Variaveis de ambiente

```bash
KEYCLOAK_SERVER_URL="https://sso.seudominio.com.br"
KEYCLOAK_REALM="meu_realm"
KEYCLOAK_CLIENT_ID="minha_app"
KEYCLOAK_CLIENT_SECRET="meu_secret"
```

### 4. Initializer

```ruby
KeycloakRails.configure do |config|
  config.server_url = ENV.fetch("KEYCLOAK_SERVER_URL")
  config.realm = ENV.fetch("KEYCLOAK_REALM")
  config.client_id = ENV.fetch("KEYCLOAK_CLIENT_ID")
  config.client_secret = ENV.fetch("KEYCLOAK_CLIENT_SECRET")

  config.resource_model_class_name = "Usuario"
  config.permission_name = nil

  config.skip_paths = [
    %r{\A/keycloak},
    %r{\A/assets},
    %r{\A/favicon}
  ]

  config.after_sign_in_path = "/"
  config.after_sign_out_path = "/"
  config.permission_denied_path = "/"
  config.token_expiration_tolerance = 10
  config.create_user_on_first_login = false
  config.ssl_verify = true
end
```

### 5. Proteger controllers

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_keycloak_user!
end
```

No escopo default, a engine e montada automaticamente em /keycloak.

## Guia 2: Multiplos escopos

Use quando a aplicacao tem dominios separados, por exemplo servidor e cidadao.

### 1. Gerar initializer por escopo

```bash
rails g keycloak:install servidor
rails g keycloak:install cidadao
```

### 2. Configurar modelos

```bash
rails g keycloak Servidor servidor
rails g keycloak Cidadao cidadao
rails db:migrate
```

### 3. Variaveis de ambiente

```bash
KEYCLOAK_SERVIDOR_SERVER_URL="https://sso.exemplo.gov.br"
KEYCLOAK_SERVIDOR_REALM="servidor"
KEYCLOAK_SERVIDOR_CLIENT_ID="app_servidor"
KEYCLOAK_SERVIDOR_CLIENT_SECRET="secret_servidor"

KEYCLOAK_CIDADAO_SERVER_URL="https://sso.exemplo.gov.br"
KEYCLOAK_CIDADAO_REALM="cidadao"
KEYCLOAK_CIDADAO_CLIENT_ID="app_cidadao"
KEYCLOAK_CIDADAO_CLIENT_SECRET="secret_cidadao"
```

### 4. Initializer por escopo

```ruby
KeycloakRails.configure(:servidor) do |config|
  config.server_url = ENV.fetch("KEYCLOAK_SERVIDOR_SERVER_URL")
  config.realm = ENV.fetch("KEYCLOAK_SERVIDOR_REALM")
  config.client_id = ENV.fetch("KEYCLOAK_SERVIDOR_CLIENT_ID")
  config.client_secret = ENV.fetch("KEYCLOAK_SERVIDOR_CLIENT_SECRET")

  config.resource_model_class_name = "Servidor"
  config.permission_name = "access_app_servidor"

  config.skip_paths = [
    %r{\A/keycloak/servidor},
    %r{\A/assets},
    %r{\A/favicon}
  ]

  config.after_sign_in_path = "/admin"
  config.after_sign_out_path = "/"
  config.permission_denied_path = "/"
end

KeycloakRails.configure(:cidadao) do |config|
  config.server_url = ENV.fetch("KEYCLOAK_CIDADAO_SERVER_URL")
  config.realm = ENV.fetch("KEYCLOAK_CIDADAO_REALM")
  config.client_id = ENV.fetch("KEYCLOAK_CIDADAO_CLIENT_ID")
  config.client_secret = ENV.fetch("KEYCLOAK_CIDADAO_CLIENT_SECRET")

  config.resource_model_class_name = "Cidadao"
  config.permission_name = nil

  config.skip_paths = [
    %r{\A/keycloak/cidadao},
    %r{\A/assets},
    %r{\A/favicon}
  ]
end
```

### 5. Rotas

Para escopos nomeados, monte manualmente no routes.rb:

```ruby
Rails.application.routes.draw do
  mount KeycloakRails::Engine,
        at: "/keycloak/servidor",
        as: "keycloak_servidor",
        defaults: { keycloak_scope: "servidor" }

  mount KeycloakRails::Engine,
        at: "/keycloak/cidadao",
        as: "keycloak_cidadao",
        defaults: { keycloak_scope: "cidadao" }
end
```

### 6. Controller base por area

```ruby
class Admin::BaseController < ApplicationController
  def keycloak_scope
    :servidor
  end

  before_action :authenticate_keycloak_user!
end

class Portal::BaseController < ApplicationController
  def keycloak_scope
    :cidadao
  end
end
```

## Uso em views

Helpers disponiveis:

- current_user
- keycloak_user_signed_in?
- keycloak_session_active?
- keycloak_login_path
- keycloak_logout_path
- keycloak_logout_button

Exemplos:

```erb
<% if keycloak_user_signed_in? %>
  <%= keycloak_logout_button "Sair", class: "btn btn-primary" %>
<% else %>
  <%= link_to "Entrar", keycloak_login_path %>
<% end %>
```

Em escopo nomeado, os helpers acima usam o keycloak_scope do controller atual. Se o controller nao define keycloak_scope, o fallback e o escopo default.

## Rotas expostas

Escopo default (auto-mount):

- GET /keycloak/login
- GET /keycloak/callback
- DELETE /keycloak/logout

Escopo nomeado servidor (mount manual):

- GET /keycloak/servidor/login
- GET /keycloak/servidor/callback
- DELETE /keycloak/servidor/logout

## Modelo

Seu modelo precisa incluir o concern e ter email e keycloak_id.

```ruby
class Usuario < ApplicationRecord
  include KeycloakRails::Models::Concerns::KeycloakAuthenticatable
end
```

## Referencia de configuracao

Campos suportados em KeycloakRails::Configuration:

- server_url
- realm
- client_id
- client_secret
- resource_model_class_name
- permission_name
- skip_paths
- token_expiration_tolerance
- logger
- after_sign_in_path
- after_sign_out_path
- permission_denied_path
- create_user_on_first_login
- ssl_verify
- ca_file

## Erros comuns e como corrigir

### 1) No route matches [GET] "/keycloak/keycloak/callback"

Causa comum: callback sendo montado com prefixo duplicado em cenario de engine montada.

Situacao atual da gem: callback ja e resolvido pela rota atual da engine, evitando /keycloak/keycloak/callback.

Se ainda ocorrer na aplicacao:

- valide o mount no routes.rb
- valide o Redirect URI no Keycloak
- confirme que a URL cadastrada e exatamente a rota de callback do escopo

### 2) KeycloakRails::ConfigurationError: client_id e obrigatorio

Significa que o escopo em uso nao recebeu client_id valido.

Checklist:

- confirme variaveis de ambiente do escopo
- confira se o initializer usa as variaveis corretas
- confira se o request caiu no escopo certo

Exemplo: se o app usa apenas escopo servidor, logout correto e /keycloak/servidor/logout. Se bater em /keycloak/logout, esta usando escopo default.

### 3) Logout vai para /keycloak/logout em app multi-escopo

Causa: view/controller no escopo default ou rota hardcoded.

Correcao:

- defina keycloak_scope no controller da area
- use keycloak_logout_button ou keycloak_logout_path
- evite string literal /keycloak/logout

## Seguranca

- State OAuth validado no callback
- Protecao contra open redirect no retorno pos-login
- Validacao de assinatura JWT via JWKS
- Sessao separada por escopo

## Licenca

MIT
