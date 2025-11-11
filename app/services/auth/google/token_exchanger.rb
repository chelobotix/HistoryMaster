require "net/http"
require "json"
require "jwt"

module Auth
  module Google
    class TokenExchanger
      include BaseService

      private attr_reader :code
      attr_reader :google_payload

      GOOGLE_CLIENT_ID = ENV["GOOGLE_CLIENT_ID"].freeze
      private_constant :GOOGLE_CLIENT_ID
      GOOGLE_CLIENT_SECRET = ENV["GOOGLE_CLIENT_SECRET"].freeze
      private_constant :GOOGLE_CLIENT_SECRET
      GOOGLE_TOKEN_EXCHANGE_URL = ENV["GOOGLE_TOKEN_EXCHANGE_URL"].freeze
      private_constant :GOOGLE_TOKEN_EXCHANGE_URL
      GOOGLE_REDIRECT_URL = ENV["GOOGLE_REDIRECT_URL"].freeze
      private_constant :GOOGLE_REDIRECT_URL

      def initialize(code:)
        @code = code
        @google_payload = nil
      end

      def call
        handle_exchange_code
        set_as_valid!

      rescue => e
        set_as_invalid!
        set_errors(e.message)
      end

      private

      def handle_exchange_code
        response = exchange_code_request
        id_token = handle_exchange_code_response(response)
        @google_payload = google_data_decoder(id_token)
      end

      def exchange_code_request
        uri = URI.parse(GOOGLE_TOKEN_EXCHANGE_URL)
        decoded_code = URI.decode_www_form_component(code)

        Net::HTTP.post_form(uri, {
          code: decoded_code,
          client_id: GOOGLE_CLIENT_ID,
          client_secret: GOOGLE_CLIENT_SECRET,
          redirect_uri: GOOGLE_REDIRECT_URL,
          grant_type: "authorization_code"
        })

      rescue URI::InvalidComponentError => e
        raise StandardError.new("code: #{Errors::GlobalCodes::INVALID_COMPONENT_ERROR}: Invalid component: #{e.message}")
      end

      def handle_exchange_code_response(response)
        unless response.is_a?(Net::HTTPSuccess)
          raise StandardError.new("code: #{Errors::GlobalCodes::EXTERNAL_API_ERROR}: Failed to exchange code: #{response.body}")
        end

        google_data = JSON.parse(response.body).with_indifferent_access
        id_token = google_data[:id_token]

        if id_token.blank?
          raise StandardError.new("code: #{Errors::GlobalCodes::EXTERNAL_API_ERROR}: Failed to exchange code: #{response.body}")
        end

        id_token

      rescue JSON::ParserError => e
        raise StandardError.new("code: #{Errors::GlobalCodes::JSON_PARSER_ERROR}: Failed to parse JSON: #{e.message}")
      end

      def google_data_decoder(id_token)
        JWT.decode(id_token, nil, false).first.with_indifferent_access

      rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError, JWT::InvalidIatError, JWT::ImmatureSignature => e
        raise StandardError.new("code: #{Errors::GlobalCodes::JWT_DECODE_ERROR}: Failed to decode JWT: #{e.message}")
      rescue JSON::ParserError => e
        raise StandardError.new("code: #{Errors::GlobalCodes::JSON_PARSER_ERROR}: Failed to parse JSON: #{e.message}")
      end
    end
  end
end
