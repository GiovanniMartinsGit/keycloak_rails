# frozen_string_literal: true

require "monitor"

module KeycloakRails
  module Services
    class TokenService < BaseService
      JWKS_CACHE_TTL = 3600 # 1 hora

      def exchange_code(code, redirect_uri)
        log_info("Trocando authorization code por tokens")

        http_client.post(config.token_url, body: {
          grant_type: "authorization_code",
          client_id: config.client_id,
          client_secret: config.client_secret,
          code: code,
          redirect_uri: redirect_uri
        })
      end

      def refresh_token(refresh_token_value)
        log_info("Renovando access token via refresh token")

        http_client.post(config.token_url, body: {
          grant_type: "refresh_token",
          client_id: config.client_id,
          client_secret: config.client_secret,
          refresh_token: refresh_token_value
        })
      end

      def revoke_token(refresh_token_value)
        log_info("Revogando sessão no Keycloak")

        http_client.post(config.logout_url, body: {
          client_id: config.client_id,
          client_secret: config.client_secret,
          refresh_token: refresh_token_value
        })
      end

      def decode_token(access_token)
        jwks = fetch_jwks
        JWT.decode(
          access_token,
          nil,
          true,
          algorithms: ["RS256"],
          jwks: jwks,
          iss: config.realm_url,
          verify_iss: true,
          verify_aud: false
        ).first
      rescue JWT::ExpiredSignature
        raise TokenExpiredError, "Token expirado"
      rescue JWT::DecodeError => e
        raise TokenInvalidError, "Token inválido"
      end

      def token_expired?(access_token)
        decode_token(access_token)
        false
      rescue TokenExpiredError
        true
      rescue TokenInvalidError
        true
      end

      private

      def fetch_jwks
        @@jwks_mutex ||= Monitor.new
        @@jwks_mutex.synchronize do
          if @@jwks_cache && @@jwks_fetched_at && (Time.now.to_i - @@jwks_fetched_at) < JWKS_CACHE_TTL
            return @@jwks_cache
          end

          log_info("Buscando JWKS do Keycloak")
          response = http_client.get(config.certs_url)
          @@jwks_cache = JWT::JWK::Set.new(response)
          @@jwks_fetched_at = Time.now.to_i
          @@jwks_cache
        end
      end

      class << self
        def clear_jwks_cache!
          @@jwks_cache = nil
          @@jwks_fetched_at = nil
        end
      end

      @@jwks_cache = nil
      @@jwks_fetched_at = nil
    end
  end
end
