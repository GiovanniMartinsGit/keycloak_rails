# frozen_string_literal: true

module KeycloakRails
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class TokenExpiredError < AuthenticationError; end
  class TokenInvalidError < AuthenticationError; end
  class PermissionDeniedError < Error; end
  class UserNotFoundError < Error; end
  class ConfigurationError < Error; end
  class HttpError < Error
    attr_reader :status, :response_body

    def initialize(message = nil, status: nil, response_body: nil)
      @status = status
      @response_body = response_body
      super(message)
    end
  end
end
