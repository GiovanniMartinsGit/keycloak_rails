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

      # Fetches (and caches) the JWKS for the realm associated with this scope.
      #
      # Security: the cache is keyed by the full certs_url so that two scopes
      # pointing at different realms (or different Keycloak instances) never
      # share signing keys — preventing token confusion / cross-realm replay.
      def fetch_jwks
        certs_url = config.certs_url

        self.class.jwks_mutex.synchronize do
          fetched_at = self.class.jwks_fetched_ats[certs_url]
          cached     = self.class.jwks_caches[certs_url]

          if cached && fetched_at && (Time.now.to_i - fetched_at) < JWKS_CACHE_TTL
            return cached
          end

          log_info("Atualizando chaves de validação (realm: #{config.realm})")
          response = http_client.get(certs_url)
          self.class.jwks_caches[certs_url]     = JWT::JWK::Set.new(response)
          self.class.jwks_fetched_ats[certs_url] = Time.now.to_i
          self.class.jwks_caches[certs_url]
        end
      end

      class << self
        def jwks_mutex
          @jwks_mutex ||= Monitor.new
        end

        def jwks_caches
          @jwks_caches ||= {}
        end

        def jwks_fetched_ats
          @jwks_fetched_ats ||= {}
        end

        def clear_jwks_cache!
          jwks_mutex.synchronize do
            @jwks_caches     = {}
            @jwks_fetched_ats = {}
          end
        end

        # Clear the JWKS cache for a specific realm (e.g. after key rotation).
        def clear_jwks_cache_for!(certs_url)
          jwks_mutex.synchronize do
            jwks_caches.delete(certs_url)
            jwks_fetched_ats.delete(certs_url)
          end
        end
      end
    end
  end
end
