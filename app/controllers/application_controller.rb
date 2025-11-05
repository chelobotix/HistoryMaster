class ApplicationController < ActionController::Base
  include DeviseTokenAuth::Concerns::SetUserByToken
  protect_from_forgery with: :null_session
  respond_to :json
  allow_browser versions: :modern

  before_action :authenticate_user!, unless: :devise_controller?
end
