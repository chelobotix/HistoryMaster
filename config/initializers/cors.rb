require "uri"

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.development?
      origins "*"
      #"http://127.0.0.1:3000",
              # "http://localhost:3000",
              # "http://localhost:4200"
    elsif Rails.env.production?
      origins do |origin, env|
        return false if origin.nil?

        allowed_domains = [ "shipedge.com" ]
        begin
          uri = URI.parse(origin)
          allowed_domains.include?(uri.host) && uri.scheme == "https" && uri.user.nil? && uri.password.nil?

        rescue URI::InvalidURIError
          Rails.logger.warn("Blocked invalid origin: #{origin}")
          false
        end
      end
    end

    # The resource(s) to allow CORS for
    resource "*",
             headers: :any,
             methods: [ :get, :post, :options, :head ]
  end
end
