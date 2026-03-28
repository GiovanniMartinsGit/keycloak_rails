# frozen_string_literal: true

require "monitor"

module KeycloakRails
  class TokenStore
    CLEANUP_INTERVAL = 300 # 5 minutos

    @mutex = Monitor.new
    @store = {}
    @last_cleanup = Time.now.to_i

    class << self
      def store(user_id, token_data)
        cleanup_expired!

        ttl = token_data["expires_in"].to_i
        # Refresh tokens geralmente duram mais. Usar 2x o expires_in como margem
        effective_ttl = [ttl * 2, 1800].max

        data = {
          "access_token" => token_data["access_token"],
          "refresh_token" => token_data["refresh_token"],
          "id_token" => token_data["id_token"],
          "expires_at" => Time.now.to_i + ttl,
          "purge_at" => Time.now.to_i + effective_ttl
        }
        @mutex.synchronize { @store[user_id.to_s] = data }
        data
      end

      def read(user_id)
        return nil if user_id.blank?

        @mutex.synchronize do
          data = @store[user_id.to_s]
          return nil unless data

          if data["purge_at"] && data["purge_at"] < Time.now.to_i
            @store.delete(user_id.to_s)
            return nil
          end

          data
        end
      end

      def delete(user_id)
        return if user_id.blank?

        @mutex.synchronize { @store.delete(user_id.to_s) }
      end

      def access_token(user_id)
        read(user_id)&.dig("access_token")
      end

      def refresh_token(user_id)
        read(user_id)&.dig("refresh_token")
      end

      def id_token(user_id)
        read(user_id)&.dig("id_token")
      end

      def clear_all!
        @mutex.synchronize { @store.clear }
      end

      def size
        @mutex.synchronize { @store.size }
      end

      private

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
