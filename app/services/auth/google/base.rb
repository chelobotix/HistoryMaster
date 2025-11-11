module Auth
  module Google
    class Base
      include BaseService

      private attr_reader :code, :state_token, :request, :google_payload
      attr_reader :auth_headers

      def initialize(code:, state_token:, request:, dependencies: {})
        @code = code
        @request = request
        @state_token = state_token
        @token_exchanger_service = dependencies[:token_exchanger]
        @state_token_validator_service = dependencies[:state_token_validator]
        @user_payload_processor_service = dependencies[:user_payload_processor]
        @google_payload = nil
        @auth_headers = nil
      end

      def call
        handle_google_exchange
        set_as_valid!

      rescue => e
        set_as_invalid!
        set_errors(e.message)
      end

      private

      def handle_google_exchange
        validate_params
        validate_state_token
        exchange_token
        handle_google_payload
      end

      def validate_params
        if code.blank? || state_token.blank? || request.blank?
          raise StandardError.new("code: #{Errors::GlobalCodes::EMPTY_PARAMS}: Some parameters are missing")
        end
      end

      def validate_state_token
        service = @state_token_validator_service.new(state_token: state_token, request: request)
        service.call

        unless service.valid?
          raise StandardError.new(service.errors)
        end
      end

      def exchange_token
        service = @token_exchanger_service.new(code: code)
        service.call

        if service.valid?
          @google_payload = service.google_payload
        else
          raise StandardError.new(service.errors)
        end
      end

      def handle_google_payload
        service = @user_payload_processor_service.new(google_payload: google_payload)
        service.call

        if service.valid?
          @auth_headers = service.auth_headers
        else
          raise StandardError.new(service.errors)
        end
      end
    end
  end
end
