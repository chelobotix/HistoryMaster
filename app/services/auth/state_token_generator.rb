module Auth
  class StateTokenGenerator
    include BaseService

    private attr_reader :request

    def initialize(request:)
      @request = request
    end

    def call
      generate_state_token
    end

    private

    def generate_state_token
      redis = Redis.new(url: ENV["REDIS_URL"])
      user_agent = request.user_agent
      ip_address = request.ip
      timestamp = Time.now.to_i
      random_string = SecureRandom.hex(16)
      state_token = "#{user_agent}-#{ip_address}-#{timestamp}-#{random_string}"
      state_token
    end
  end
end
