class Auth::Oauth2AuthorizationController < ApplicationController
  require "net/http"
  require "json"

  skip_before_action :authenticate_user!, only: [ :google_state_token ]

  def google_state_token
    binding.break
    service = Auth::StateTokenGenerator.new(request: request, provider: :GOOGLE)
    service.call

    if service.valid?
      response.headers['State-Token'] = service.state_token
      render json: { result: "ok" }, status: :ok
    else
      render json: { error: service.errors }, status: :unprocessable_entity
    end
  end

  def google_callback
    binding.break

    code = params[:code]

    return render json: { error: "Code is required" }, status: :unauthorized if code.blank?

    uri = URI("https://oauth2.googleapis.com/token")
    res = Net::HTTP.post_form(uri, {
      code: code,
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      redirect_uri: "#{ENV['API_URL']}/auth/google_callback",
      grant_type: "authorization_code"
    })
    google_data = JSON.parse(res.body)
    id_token = google_data["id_token"]

    # Validar token con Google
    uri = URI("https://oauth2.googleapis.com/tokeninfo?id_token=#{id_token}")
    response = Net::HTTP.get(uri)
    google_data = JSON.parse(response)

    if google_data["email_verified"] == "true"
      user = User.find_or_create_by(email: google_data["email"]) do |u|
        u.password = SecureRandom.hex(10)
        u.name = google_data["name"]
      end

      # Crear tokens y establecerlos en los headers de la respuesta
      auth_headers = user.create_new_auth_token
      response.headers.merge!(auth_headers)

      render json: { user: user }, status: :ok
    else
      render json: { error: "Invalid Google token" }, status: :unauthorized
    end
  end

  def state
  end
end
