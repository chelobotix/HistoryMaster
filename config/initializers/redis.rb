require "connection_pool"
require "redis"

Rails.application.config.after_initialize do
  begin
    RedisService.instance.with { |redis| redis.ping }
    Rails.logger.info "✅ Redis connection established"
  rescue => e
    Rails.logger.error "❌ Redis connection failed: #{e.message}"
    raise e
  end
end
