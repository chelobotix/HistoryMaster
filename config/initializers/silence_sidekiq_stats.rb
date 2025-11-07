# Silencia los logs de health checks de Sidekiq
Rails.application.config.middleware.insert_before Rails::Rack::Logger, Rack::SilentLogger, urls: [
  "/sidekiq/stats",
  "/sidekiq/stats.json"
]

# Definición del middleware
class Rack::SilentLogger
  def initialize(app, options = {})
    @app = app
    @urls = options[:urls] || []
  end

  def call(env)
    if @urls.any? { |url| env["PATH_INFO"].start_with?(url) }
      # Silencia el logger para estos paths
      Rails.logger.silence do
        @app.call(env)
      end
    else
      @app.call(env)
    end
  end
end
