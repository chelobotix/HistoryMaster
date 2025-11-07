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

    def initialize(request:, provider:, encryptor: EncryptorService.instance)
      @request = request
      @provider = provider
      @redis_service = RedisService.instance
      @encryptor = encryptor
      @state_token = nil
    end

    def call
      generate_state_token
      set_as_valid!

    rescue => e
      set_as_invalid!
      set_errors(e.message)
    end

    private

    def generate_state_token
      validator
      data_from_request = build_data_from_request
      key = build_key_name

      persist_data_in_redis(key, data_from_request)
      encrypt_data(key)
    end

    def validator
      validate_request
      validate_provider
    end

    def validate_request
      raise "Request is invalid" if request.blank? || !request.is_a?(ActionDispatch::Request)
    end

    def validate_provider
      raise "Provider is invalid" unless PROVIDERS.include?(provider)
    end

    def build_data_from_request
      {
        user_agent: request.user_agent,
        ip_address: request.ip,
      }
    end

    def build_key_name
      "STATE_TOKEN:#{provider.to_s}:#{Time.now.to_i}:#{SecureRandom.hex(16)}"
    end

    def persist_data_in_redis(key, data)
      redis_service.set(
        key, data.to_json, ex: EXPIRATION_TIME)
    end

    def encrypt_data(data)
      @state_token = encryptor.encrypt(data)

    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage => e
      raise "Invalid encrypted payload #{e.message}"
    end
  end
end
