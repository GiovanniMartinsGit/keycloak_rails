# frozen_string_literal: true

require "monitor"

module KeycloakRails
  class TokenStore
    CLEANUP_INTERVAL = 300 # 5 minutos

    @mutex = Monitor.new
    @store = {}
    @last_cleanup = Time.now.to_i

    class << self
      # Store token data for +user_id+ under the given +scope+.
      #
      # Security (OWASP A01 – Broken Access Control):
      #   Scope-namespaced keys prevent one scope's tokens from being read
      #   in another scope's context (e.g. a :cidadao token cannot be used
      #   to authenticate a :servidor session).
      def store(user_id, token_data, scope: :default)
        cleanup_expired!

        key = store_key(user_id, scope)
        ttl = token_data["expires_in"].to_i
        # Refresh tokens generally last longer; use 2× expires_in as purge margin
        effective_ttl = [ttl * 2, 1800].max

        data = {
          "access_token"  => token_data["access_token"],
          "refresh_token" => token_data["refresh_token"],
          "id_token"      => token_data["id_token"],
          "expires_at"    => Time.now.to_i + ttl,
          "purge_at"      => Time.now.to_i + effective_ttl
        }
        @mutex.synchronize { @store[key] = data }
        data
      end

      def read(user_id, scope: :default)
        return nil if user_id.blank?

        key = store_key(user_id, scope)
        @mutex.synchronize do
          data = @store[key]
          return nil unless data

          if data["purge_at"] && data["purge_at"] < Time.now.to_i
            @store.delete(key)
            return nil
          end

          data
        end
      end

      def delete(user_id, scope: :default)
        return if user_id.blank?

        @mutex.synchronize { @store.delete(store_key(user_id, scope)) }
      end

      def access_token(user_id, scope: :default)
        read(user_id, scope: scope)&.dig("access_token")
      end

      def refresh_token(user_id, scope: :default)
        read(user_id, scope: scope)&.dig("refresh_token")
      end

      def id_token(user_id, scope: :default)
        read(user_id, scope: scope)&.dig("id_token")
      end

      def clear_all!
        @mutex.synchronize { @store.clear }
      end

      def size
        @mutex.synchronize { @store.size }
      end

      private

      # Compose the in-memory store key.
      # :default scope keeps bare user_id strings for backward compatibility.
      # Named scopes prefix with "<scope>:" to guarantee isolation.
      def store_key(user_id, scope)
        scope = scope.to_sym
        scope == :default ? user_id.to_s : "#{scope}:#{user_id}"
      end

      def cleanup_expired!
        now = Time.now.to_i
        return if (now - @last_cleanup) < CLEANUP_INTERVAL

        @mutex.synchronize do
          return if (now - @last_cleanup) < CLEANUP_INTERVAL

          @store.delete_if { |_key, data| data["purge_at"] && data["purge_at"] < now }
          @last_cleanup = now
        end
      end
    end
  end
end
