class Auth::Oauth2AuthorizationController < ApplicationController
  require "net/http"
  require "json"

  skip_before_action :authenticate_user!, only: %i[ generate_google_auth_url google_callback ]

  def generate_google_auth_url
    service = ::Auth::Google::AuthUrlGenerator.new(request: request)
    service.call

    if service.valid?
      render json: { url: service.url }, status: :ok
    else
      render json: { error: service.errors }, status: :unprocessable_entity
    end
  end

  def google_callback
    dependencies = {
      state_token_validator: Auth::StateTokenValidator,
      token_exchanger: Auth::Google::TokenExchanger,
      user_payload_processor: Auth::Google::UserPayloadProcessor
    }

    service = ::Auth::Google::Base.new(
      code: params[:code],
      state_token: params[:state_token],
      request: request,
      dependencies: dependencies
    )

    service.call

    if service.valid?
      response.headers.merge!(service.auth_headers)
      render json: { message: "ok" }, status: :ok
    else
      render json: { error: service.errors }, status: :unprocessable_entity
    end
  end

  def state
  end
end
