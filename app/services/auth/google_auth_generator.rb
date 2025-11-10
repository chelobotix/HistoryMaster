module Auth
  class GoogleAuthGenerator
    include BaseService

    private attr_reader :request, :state_token, :state_token_service
    attr_reader :url

    BASE_URL = ENV["BASE_URL"].freeze
    private_constant :BASE_URL
    GOOGLE_CLIENT_ID = ENV["GOOGLE_CLIENT_ID"].freeze
    private_constant :GOOGLE_CLIENT_ID
    GOOGLE_REDIRECT_URL = ENV["GOOGLE_REDIRECT_URL"].freeze
    private_constant :GOOGLE_REDIRECT_URL

    # Initializes a new instance of GoogleAuthGenerator
    #
    # @param request [ActionDispatch::Request] The incoming HTTP request
    # @param state_token_service [Class] The service class for generating state tokens (default: StateTokenGenerator)
    def initialize(request:, state_token_service: StateTokenGenerator)
      @request = request
      @state_token_service = state_token_service
      @state_token = nil
      @url = nil
    end

    # Executes the Google authentication URL generation process
    #
    # @return [void]
    #
    # @raise [StandardError] if an unexpected error occurs during URL generation
    def call
      generate_google_auth_url
      set_as_valid!

    rescue => e
      set_as_invalid!
      set_errors(e.code, e.message)
    end

    private

    # Coordinates the generation of the Google authorization URL
    #
    # @return [void]
    def generate_google_auth_url
      generate_state_token
      generate_url
    end

    # Generates a state token for the Google authentication request
    #
    # @return [void]
    #
    # @raise [StandardError] if the state token generation fails
    def generate_state_token
      service = state_token_service.new(request: request, provider: :GOOGLE)
      service.call

      if service.valid?
        @state_token = service.state_token
      else
        raise service.errors
      end
    end

    # Builds the Google OAuth authorization URL with all required parameters
    #
    # @return [void]
    def generate_url
      @url = "#{BASE_URL}?state=#{state_token}&client_id=#{GOOGLE_CLIENT_ID}&redirect_uri=#{GOOGLE_REDIRECT_URL}&response_type=code&scope=email profile"
    end
  end
end
