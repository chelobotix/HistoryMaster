Rails.application.routes.draw do
  require "sidekiq/web"

  # Sidekiq web interface
  mount Sidekiq::Web => "/sidekiq"

  mount_devise_token_auth_for "User", at: "auth"

  namespace :api do
    namespace :v1 do
      get "testo/test" => "testo#test"
      get "testo/confirm" => "testo#confirm"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
