# frozen_string_literal: true

module KeycloakRails
  module Http
    class Client
      include Logging

      def initialize(base_url: nil)
        @base_url = base_url || KeycloakRails.configuration.server_url
      end

      def post(url, body: {}, headers: {})
        response = connection.post(url) do |req|
          req.headers.merge!(headers)
          req.body = body
        end
        handle_response(response)
      end

      def get(url, headers: {})
        response = connection.get(url) do |req|
          req.headers.merge!(headers)
        end
        handle_response(response)
      end

      private

      def connection
        @connection ||= Faraday.new(url: @base_url, ssl: ssl_options) do |conn|
          conn.request :url_encoded
          conn.response :json, content_type: /\bjson$/
          conn.adapter Faraday.default_adapter
          conn.options.timeout = 30
          conn.options.open_timeout = 10
        end
      end

      def ssl_options
        opts = { verify: KeycloakRails.configuration.ssl_verify }
        ca_file = KeycloakRails.configuration.ca_file
        opts[:ca_file] = ca_file if ca_file.present?
        opts
      end

      def handle_response(response)
        case response.status
        when 200..299
          response.body
        when 401
          raise AuthenticationError, "Autenticação falhou (status 401)"
        when 403
          raise PermissionDeniedError, "Permissão negada (status 403)"
        else
          raise HttpError.new(
            "Keycloak retornou status #{response.status}",
            status: response.status,
            response_body: nil
          )
        end
      end
    end
  end
end
