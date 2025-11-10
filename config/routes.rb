Rails.application.routes.draw do
  require "sidekiq/web"

  # Sidekiq web interface
  mount Sidekiq::Web => "/sidekiq"


  mount_devise_token_auth_for "User", at: "auth"

  namespace :api do
    namespace :v1 do
      get "testo/test", to: "testo#test"
      get "testo/confirm", to: "testo#confirm"
    end
  end

  namespace :auth do
    get "generate_google_auth_url", to: "oauth2_authorization#generate_google_auth_url"
    get "google_callback", to: "oauth2_authorization#google_callback"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
