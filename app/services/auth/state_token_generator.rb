module Auth
  class StateTokenGenerator
    include BaseService

    PROVIDERS = [ :GOOGLE ].freeze
    private_constant :PROVIDERS

    EXPIRATION_TIME = ENV["STATE_TOKEN_EXPIRATION_TIME"].to_i.minutes.freeze
    private_constant :EXPIRATION_TIME

    STATE_TOKEN_SECRET = ENV["STATE_TOKEN_SECRET"].freeze
    private_constant :STATE_TOKEN_SECRET

    private attr_reader :request, :provider, :encryptor, :redis_service
    attr_reader :state_token

    # Initializes a new instance of StateTokenGenerator
    #
    # @param request [ActionDispatch::Request] The incoming HTTP request
    # @param provider [Symbol] The authentication provider (e.g., :GOOGLE)
    # @param encryptor [EncryptorService] The encryption service instance
    def initialize(request:, provider:, encryptor: EncryptorService.instance)
      @request = request
      @provider = provider
      @redis_service = RedisService.instance
      @encryptor = encryptor
      @state_token = nil
    end

    # Executes the state token generation process
    #
    # @return [void]
    # @raise [StandardError] If an error occurs during token generation
    def call
      generate_state_token
      set_as_valid!

    rescue => e
      set_as_invalid!
      set_errors(e.code, e.message)
    end

    private

    # Generates a new encrypted state token and stores related data in Redis
    #
    # @return [void]
    def generate_state_token
      validator
      data_from_request = build_data_from_request
      key = build_key_name

      persist_data_in_redis(key, data_from_request)
      encrypt_data(key)
    end

    # Validates both the request and provider parameters
    #
    # @return [void]
    # @raise [StandardError] If validation fails
    def validator
      validate_request
      validate_provider
    end

    # Validates the request object
    #
    # @return [void]
    # @raise [StandardError] If the request is nil or not an ActionDispatch::Request
    def validate_request
      if request.blank? || !request.is_a?(ActionDispatch::Request)
        raise Errors::Custom.new(code: ErrorCodes::INVALID_REQUEST_TYPE, message: "Request is invalid")
      end
    end

    # Validates the provider symbol
    #
    # @return [void]
    # @raise [StandardError] If the provider is not included in PROVIDERS
    def validate_provider
      if !PROVIDERS.include?(provider)
        raise Errors::Custom.new(code: ErrorCodes::INVALID_PROVIDER, message: "Provider is invalid")
      end
    end

    # Builds a data hash from the current request
    #
    # @return [Hash] Contains user agent and IP address
    def build_data_from_request
      {
        user_agent: request.user_agent,
        ip_address: request.ip
      }
    end

    # Builds a unique Redis key for storing the state token data
    #
    # @return [String] The generated Redis key
    def build_key_name
      "STATE_TOKEN:#{provider}:#{Time.now.to_i}:#{SecureRandom.hex(16)}"
    end

    # Persists data in Redis with expiration time
    #
    # @param key [String] The Redis key name
    # @param data [Hash] The data to store
    # @return [void]
    def persist_data_in_redis(key, data)
      redis_service.set(
        key, data.to_json, ex: EXPIRATION_TIME
      )

    rescue Redis::CannotConnectError => e
      raise Errors::Custom.new(
        code: Errors::GlobalCodes::REDIS_CONNECTION_ERROR,
        message: "Redis connection error: #{e.message}"
      )
    end

    # Encrypts the Redis key to generate the final state token
    #
    # @param data [String] The data to encrypt
    # @return [void]
    # @raise [StandardError] If encryption fails
    def encrypt_data(data)
      @state_token = encryptor.encrypt(data)

    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage => e
      raise Errors::Custom.new(
        code: ErrorCodes::INVALID_ENCRYPTED_PAYLOAD,
        message: "Invalid encrypted payload #{e.message}"
      )
    end
  end
end
