class RedisService
  include Singleton

  attr_reader :connection

  def initialize
    @connection = ConnectionPool.new(size: pool_size, timeout: timeout) do
      Redis.new(redis_config)
    end
  end

  def with(&block)
    connection.with(&block)
  end

  def get(key)
    with { |redis| redis.get(key) }
  end

  def set(key, value, options = {})
    with do |redis|
      if options[:ex]
        redis.setex(key, options[:ex], value)
      else
        redis.set(key, value)
      end
    end
  end

  def del(key)
    with { |redis| redis.del(key) }
  end

  def exists?(key)
    with { |redis| redis.exists?(key) }
  end

  private

  def redis_config
    {
      url: ENV["REDIS_URL"],
      ssl_params: Rails.env.production? ? { verify_mode: OpenSSL::SSL::VERIFY_NONE } : nil
    }
  end

  def pool_size
    ENV["REDIS_POOL_SIZE"].to_i
  end

  def timeout
    ENV["REDIS_TIMEOUT"].to_i
  end
end
