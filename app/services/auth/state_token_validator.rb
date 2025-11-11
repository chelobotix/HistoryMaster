module Auth
  class StateTokenValidator
    include BaseService

    private attr_reader :state_token, :redis_service, :encryptor_service, :request

    def initialize(state_token:, request:)
      @state_token = state_token
      @request = request
      @encryptor_service = EncryptorService.instance
      @redis_service = RedisService.instance
    end

    def call
      validate_state_token
      set_as_valid!

    rescue => e
      set_as_invalid!
      set_errors(e.message)
    end

    private

    def validate_state_token
      validate_params

      redis_key = decrypt_state_token
      redis_data = get_redis_data(redis_key)

      validate_data(redis_data)
    end

    def validate_params
      if state_token.blank? || request.blank?
        raise StandardError.new("code: #{Errors::GlobalCodes::EMPTY_PARAMS}: State token and request are required")
      end
    end

    def decrypt_state_token
      redis_key = encryptor_service.decrypt(state_token)

      if redis_key.blank?
        raise StandardError.new("code: #{Errors::GlobalCodes::INVALID_STATE_TOKEN}: Invalid state token")
      end

      redis_key
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage => e
      error_code = Errors::GlobalCodes::INVALID_ENCRYPTED_PAYLOAD
      raise StandardError.new("code: #{error_code}: Invalid encrypted payload: #{e.message}")
    end

    def get_redis_data(redis_key)
      redis_data = redis_service.get(redis_key)

      if redis_data.blank?
        raise StandardError.new("code: #{Errors::GlobalCodes::INVALID_REDIS_KEY}: Invalid redis key")
      end

      parsed_data = JSON.parse(redis_data).with_indifferent_access

      redis_service.del(redis_key)

      parsed_data
    rescue JSON::ParserError => e
      raise StandardError.new("code: #{Errors::GlobalCodes::JSON_PARSER_ERROR}: Failed to parse JSON: #{e.message}")
    end

    def validate_data(redis_data)
      if redis_data[:user_agent] != request.user_agent || redis_data[:ip_address] != request.ip
        raise StandardError.new("code: #{Errors::GlobalCodes::INVALID_DATA}: Invalid token data")
      end
    end
  end
end
